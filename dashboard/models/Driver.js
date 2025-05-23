const bcrypt = require('bcryptjs');
const { supabase } = require('../server');

// Helper function to hash password
async function hashPassword(password) {
  const salt = await bcrypt.genSalt(10);
  return await bcrypt.hash(password, salt);
}

// Driver model
const Driver = {
  // Create a new driver
  async create(driverData) {
    // Hash the password
    const hashedPassword = await hashPassword(driverData.password);
    
    // Prepare driver data for insertion
    const driver = {
      name: driverData.name,
      email: driverData.email,
      password: hashedPassword,
      phone: driverData.phone,
      license_number: driverData.licenseNumber,
      vehicle_details: driverData.vehicleDetails,
      is_available: true,
      rating: 0,
      total_rides: 0,
      created_at: new Date().toISOString()
    };
    
    // Insert into Supabase
    const { data, error } = await supabase
      .from('drivers')
      .insert(driver)
      .select()
      .single();
    
    if (error) throw new Error(error.message);
    return data;
  },
  
  // Find a driver by email
  async findByEmail(email) {
    const { data, error } = await supabase
      .from('drivers')
      .select('*')
      .eq('email', email)
      .single();
    
    if (error && error.code !== 'PGRST116') throw new Error(error.message);
    return data;
  },
  
  // Find a driver by ID
  async findById(id) {
    const { data, error } = await supabase
      .from('drivers')
      .select('*')
      .eq('id', id)
      .single();
    
    if (error && error.code !== 'PGRST116') throw new Error(error.message);
    return data;
  },
  
  // Update driver
  async update(id, updateData) {
    const { data, error } = await supabase
      .from('drivers')
      .update(updateData)
      .eq('id', id)
      .select()
      .single();
    
    if (error) throw new Error(error.message);
    return data;
  },
  
  // Compare password
  async comparePassword(plainPassword, hashedPassword) {
    return await bcrypt.compare(plainPassword, hashedPassword);
  }
};

module.exports = Driver; 