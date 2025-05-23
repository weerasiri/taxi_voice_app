const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const Ride = require('../models/Ride');
const Driver = require('../models/Driver');

// @route   GET api/rides
// @desc    Get all available ride requests
// @access  Private
router.get('/', auth, async (req, res) => {
  try {
    const rides = await Ride.findRequested();
    res.json(rides);
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server error');
  }
});

// @route   GET api/rides/driver
// @desc    Get all rides for the current driver
// @access  Private
router.get('/driver', auth, async (req, res) => {
  try {
    const rides = await Ride.findByDriverId(req.driver.id);
    res.json(rides);
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server error');
  }
});

// @route   PUT api/rides/:id/accept
// @desc    Accept a ride
// @access  Private
router.put('/:id/accept', auth, async (req, res) => {
  try {
    const rideId = req.params.id;
    
    // Validate the ride ID
    if (!rideId || rideId === 'undefined') {
      return res.status(400).json({ msg: 'Invalid ride ID' });
    }
    
    let ride = await Ride.findById(rideId);
    
    if (!ride) {
      return res.status(404).json({ msg: 'Ride not found' });
    }
    
    if (ride.status !== 'requested') {
      return res.status(400).json({ msg: 'Ride is no longer available' });
    }
    
    // Get driver data for notification
    const driver = await Driver.findById(req.driver.id);
    
    if (!driver) {
      return res.status(404).json({ msg: 'Driver not found' });
    }
    
    // Update ride in Supabase
    const now = new Date().toISOString();
    ride = await Ride.update(rideId, {
      driver_id: req.driver.id,
      status: 'accepted',
      pickup_time: now
    });
    
    // Update driver status
    await Driver.update(req.driver.id, {
      is_available: false
    });
    
    // Prepare data for socket event
    const responseData = {
      ...ride,
      driverId: req.driver.id,
      driverName: driver.name,
      vehicleDetails: driver.vehicle_details
    };
    
    // Return the response
    res.json(responseData);
    
    // Emit socket event with the full response data
    if (req.app.io) {
      req.app.io.emit('rideAccepted', {
        rideId: ride.id,
        driverId: req.driver.id,
        driverName: driver.name,
        rideData: responseData
      });
    }
  } catch (err) {
    console.error('Error in accept ride:', err.message);
    res.status(500).send('Server error');
  }
});

// @route   PUT api/rides/user/:userId/accept
// @desc    Accept a ride from specific user
// @access  Private
router.put('/user/:userId/accept', auth, async (req, res) => {
  try {
    // Find the latest requested ride from this user
    let ride = await Ride.acceptRideFromUser(req.params.userId);
    
    if (!ride) {
      return res.status(404).json({ msg: 'No pending ride requests from this user' });
    }
    
    if (ride.status !== 'requested') {
      return res.status(400).json({ msg: 'Ride is no longer available' });
    }
    
    // Update ride
    ride = await Ride.update(ride.id, {
      driver_id: req.driver.id,
      status: 'accepted'
    });
    
    // Update driver status
    await Driver.update(req.driver.id, {
      is_available: false
    });
    
    res.json(ride);
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server error');
  }
});

// @route   PUT api/rides/:id/decline
// @desc    Decline a ride
// @access  Private
router.put('/:id/decline', auth, async (req, res) => {
  try {
    let ride = await Ride.findById(req.params.id);
    
    if (!ride) {
      return res.status(404).json({ msg: 'Ride not found' });
    }
    
    if (ride.status !== 'requested') {
      return res.status(400).json({ msg: 'Ride is no longer available' });
    }
    
    // Update ride
    ride = await Ride.update(req.params.id, {
      status: 'declined'
    });
    
    res.json(ride);
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server error');
  }
});

// @route   PUT api/rides/:id/complete
// @desc    Complete a ride
// @access  Private
router.put('/:id/complete', auth, async (req, res) => {
  try {
    let ride = await Ride.findById(req.params.id);
    
    if (!ride) {
      return res.status(404).json({ msg: 'Ride not found' });
    }
    
    if (ride.status !== 'accepted') {
      return res.status(400).json({ msg: 'Ride must be accepted before completing' });
    }
    
    if (ride.driver_id.toString() !== req.driver.id) {
      return res.status(401).json({ msg: 'Not authorized' });
    }
    
    // Update ride
    const now = new Date().toISOString();
    ride = await Ride.update(req.params.id, {
      status: 'completed',
      completion_time: now
    });
    
    // Update driver status
    const driver = await Driver.findById(req.driver.id);
    await Driver.update(req.driver.id, {
      is_available: true,
      total_rides: (driver.total_rides || 0) + 1
    });
    
    res.json(ride);
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server error');
  }
});

// @route   GET api/rides/test
// @desc    Test route
// @access  Public
router.get('/test', (req, res) => {
  res.json({ msg: 'Rides route working' });
});

module.exports = router; 