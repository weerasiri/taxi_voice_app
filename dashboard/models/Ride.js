const { supabase } = require('../server');

// Ride model
const Ride = {
  // Get all requested rides
  async findRequested() {
    const { data, error } = await supabase
      .from('rides')
      .select('*')
      .eq('status', 'requested')
      .order('request_time', { ascending: false });
    
    if (error) throw new Error(error.message);
    
    // Transform data to match expected format
    const transformedData = (data || []).map(ride => ({
      ...ride,
      _id: ride.id // Add _id field that matches the id for backward compatibility
    }));
    
    return transformedData;
  },
  
  // Get rides by driver ID
  async findByDriverId(driverId) {
    const { data, error } = await supabase
      .from('rides')
      .select('*')
      .eq('driver_id', driverId)
      .order('request_time', { ascending: false });
    
    if (error) throw new Error(error.message);
    
    // Transform data to match expected format
    const transformedData = (data || []).map(ride => ({
      ...ride,
      _id: ride.id // Add _id field that matches the id for backward compatibility
    }));
    
    return transformedData;
  },
  
  // Find a ride by ID
  async findById(id) {
    if (!id) throw new Error('Ride ID is required');
    
    const { data, error } = await supabase
      .from('rides')
      .select('*')
      .eq('id', id)
      .single();
    
    if (error && error.code !== 'PGRST116') throw new Error(error.message);
    
    if (data) {
      // Add _id field for backward compatibility
      data._id = data.id;
    }
    
    return data;
  },
  
  // Update ride
  async update(id, updateData) {
    if (!id) throw new Error('Ride ID is required');
    
    const { data, error } = await supabase
      .from('rides')
      .update(updateData)
      .eq('id', id)
      .select()
      .single();
    
    if (error) throw new Error(error.message);
    
    if (data) {
      // Add _id field for backward compatibility
      data._id = data.id;
    }
    
    return data;
  },
  
  // Create a new ride
  async create(rideData) {
    const ride = {
      user_id: rideData.userId.toString(),
      pickup: rideData.pickup,
      destination: rideData.destination,
      status: 'requested',
      fare: rideData.fare,
      payment_method: rideData.paymentMethod || 'cash',
      request_time: new Date().toISOString()
    };
    
    const { data, error } = await supabase
      .from('rides')
      .insert(ride)
      .select()
      .single();
    
    if (error) throw new Error(error.message);
    
    if (data) {
      // Add _id field for backward compatibility
      data._id = data.id;
    }
    
    return data;
  },
  
  // Accept ride from user
  async acceptRideFromUser(userId) {
    const { data, error } = await supabase
      .from('rides')
      .select('*')
      .eq('user_id', userId.toString())
      .eq('status', 'requested')
      .order('request_time', { ascending: false })
      .limit(1)
      .single();
    
    if (error && error.code !== 'PGRST116') throw new Error(error.message);
    
    if (data) {
      // Add _id field for backward compatibility
      data._id = data.id;
    }
    
    return data;
  }
};

module.exports = Ride; 