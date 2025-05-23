const jwt = require('jsonwebtoken');
const { supabase } = require('../server');

module.exports = async function(req, res, next) {
  // Get token from header
  const token = req.header('x-auth-token');

  // Check if token exists
  if (!token) {
    console.log('No token provided, using development mode');
    
    // For development, try to get first driver from database if available
    try {
      const { data } = await supabase.from('drivers').select('*').limit(1).single();
      if (data) {
        req.driver = { 
          id: data.id,
          name: data.name,
          email: data.email
        };
        return next();
      }
    } catch (error) {
      console.log('Could not find any drivers in development mode');
    }
    
    // If no driver found, use a default
    req.driver = { id: 'development-driver-id' };
    return next();
  }

  try {
    // Verify token
    const JWT_SECRET = process.env.JWT_SECRET || 'default_development_secret_key';
    const decoded = jwt.verify(token, JWT_SECRET);

    // Add driver from payload to request
    req.driver = decoded.driver;
    
    // Verify driver exists in Supabase
    const { data, error } = await supabase
      .from('drivers')
      .select('*')
      .eq('id', req.driver.id)
      .single();
    
    if (error || !data) {
      console.warn('Driver from token not found in database', error);
      return res.status(401).json({ msg: 'Driver not found. Please log in again.' });
    }
    
    // Add full driver data to request for routes to use
    req.driver = {
      ...req.driver,
      ...data
    };
    
    next();
  } catch (err) {
    console.warn('Token verification failed:', err.message);
    
    // For development purposes, try to get first driver from database
    try {
      const { data } = await supabase.from('drivers').select('*').limit(1).single();
      if (data) {
        req.driver = { 
          id: data.id,
          name: data.name,
          email: data.email
        };
        return next();
      }
    } catch (error) {
      console.log('Could not find any drivers in development mode');
      return res.status(401).json({ msg: 'Authentication failed. Please log in again.' });
    }
  }
}; 