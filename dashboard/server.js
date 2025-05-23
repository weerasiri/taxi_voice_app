const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const dotenv = require('dotenv');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');

// Load environment variables first
dotenv.config();

// Hardcoded Supabase credentials (as fallback)
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://eailmxnogvmyjchomqzc.supabase.co';
const SUPABASE_KEY = process.env.SUPABASE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVhaWxteG5vZ3ZteWpjaG9tcXpjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc5ODQ5MjIsImV4cCI6MjA2MzU2MDkyMn0.6j5ghtfHmh4MCscYv1Ybdch7fzGbBsTHXBIY81DnTS0';

// Initialize Supabase client
console.log("Connecting to Supabase at:", SUPABASE_URL);
const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

// Export supabase client for use in other files
module.exports = { supabase };

// Create Express application
const app = express();
const server = http.createServer(app);

// Set up Socket.io
const io = socketIo(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

// Make io available to our routes
app.io = io;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Serve static files from the public directory
app.use(express.static(path.join(__dirname, 'public')));

// Routes - Import after exporting the supabase client
const authRoutes = require('./routes/auth');
const driverRoutes = require('./routes/drivers');
const rideRoutes = require('./routes/rides');

// API routes
app.use('/api/auth', authRoutes);
app.use('/api/drivers', driverRoutes);
app.use('/api/rides', rideRoutes);

// Serve the dashboard SPA
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Socket.io setup for real-time communication
io.on('connection', (socket) => {
  console.log('New client connected:', socket.id);
  
  // Store driver ID for this socket if provided
  const driverId = socket.handshake.query?.driverId;
  if (driverId) {
    console.log(`Driver ${driverId} connected with socket ${socket.id}`);
    socket.driverId = driverId;
  }
  
  // Handle ride requests
  socket.on('newRideRequest', (rideData) => {
    console.log('New ride request received:', rideData.id);
    
    // Ensure the ride exists in Supabase
    async function verifyAndBroadcastRide() {
      try {
        const { data, error } = await supabase
          .from('rides')
          .select('*')
          .eq('id', rideData.id)
          .single();
          
        if (data) {
          console.log(`Verified ride ${rideData.id} exists in database, broadcasting to drivers`);
          
          // Combine data from Supabase with provided rideData for complete information
          const completeRideData = {
            ...data,
            ...rideData,
            _id: data.id // For backward compatibility
          };
          
          // Broadcast to all connected drivers
          io.emit('rideRequest', completeRideData);
        } else {
          console.error(`Ride ${rideData.id} not found in database:`, error);
        }
      } catch (err) {
        console.error('Error verifying ride:', err);
      }
    }
    
    verifyAndBroadcastRide();
  });
  
  // Handle ride acceptance
  socket.on('acceptRide', (data) => {
    console.log('Ride accepted by driver:', data.driverId, 'for ride:', data.rideId);
    
    // Update the ride in Supabase for redundancy
    async function updateRideStatus() {
      try {
        const { data: rideData, error } = await supabase
          .from('rides')
          .update({
            driver_id: data.driverId,
            status: 'accepted',
            accepted_at: new Date().toISOString()
          })
          .eq('id', data.rideId)
          .select()
          .single();
          
        if (error) {
          console.error('Error updating ride in Supabase:', error);
        } else {
          console.log(`Ride ${data.rideId} updated in database to 'accepted'`);
        }
      } catch (err) {
        console.error('Error in acceptRide socket handler:', err);
      }
    }
    
    // Broadcast acceptance to all clients
    io.emit('rideAccepted', data);
    
    // Update database status
    updateRideStatus();
  });
  
  // Handle ride rejection
  socket.on('declineRide', (data) => {
    console.log('Ride declined:', data.rideId, 'by driver:', data.driverId || 'unknown');
    
    // Update the ride in Supabase
    async function updateRideStatus() {
      try {
        // We don't mark the ride as declined in the database, just remove this driver from consideration
        console.log(`Driver ${data.driverId} declined ride ${data.rideId}`);
        
        // Broadcast to all clients
        io.emit('rideDeclined', data);
      } catch (err) {
        console.error('Error in declineRide socket handler:', err);
      }
    }
    
    updateRideStatus();
  });
  
  // Handle driver status updates
  socket.on('updateDriverStatus', (data) => {
    console.log('Driver status update:', data.driverId, data.isAvailable);
    
    // Update driver status in the database
    async function updateDriverAvailability() {
      try {
        const { error } = await supabase
          .from('drivers')
          .update({ is_available: data.isAvailable })
          .eq('id', data.driverId);
          
        if (error) {
          console.error('Error updating driver availability:', error);
        } else {
          console.log(`Driver ${data.driverId} availability updated to ${data.isAvailable}`);
          
          // Broadcast to all clients
          io.emit('driverStatusUpdated', data);
        }
      } catch (err) {
        console.error('Error in updateDriverStatus socket handler:', err);
      }
    }
    
    updateDriverAvailability();
  });
  
  // Handle driver connection notification
  socket.on('driverConnected', (data) => {
    console.log(`Driver ${data.driverId} explicitly connected`);
    socket.driverId = data.driverId;
  });
  
  // Handle ride completion
  socket.on('completeRide', (data) => {
    console.log('Ride completed by driver:', data.driverId, 'for ride:', data.rideId);
    
    // Update the ride in Supabase for redundancy
    async function updateRideStatus() {
      try {
        const now = new Date().toISOString();
        const { data: rideData, error } = await supabase
          .from('rides')
          .update({
            status: 'completed',
            completion_time: now
          })
          .eq('id', data.rideId)
          .select()
          .single();
          
        if (error) {
          console.error('Error updating ride in Supabase:', error);
        } else {
          console.log(`Ride ${data.rideId} updated in database to 'completed'`);
          
          // Update driver availability
          const { error: driverError } = await supabase
            .from('drivers')
            .update({ is_available: true })
            .eq('id', data.driverId);
            
          if (driverError) {
            console.error('Error updating driver availability:', driverError);
          }
        }
      } catch (err) {
        console.error('Error in completeRide socket handler:', err);
      }
    }
    
    // Broadcast completion to all clients
    io.emit('rideCompleted', data);
    
    // Update database status
    updateRideStatus();
  });
  
  socket.on('disconnect', () => {
    console.log('Client disconnected:', socket.id, socket.driverId ? `(Driver: ${socket.driverId})` : '');
  });
});

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Connected to Supabase at ${SUPABASE_URL}`);
}); 