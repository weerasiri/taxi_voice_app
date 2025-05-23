const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const Driver = require('../models/Driver');

// @route   GET api/drivers/me
// @desc    Get current driver profile
// @access  Private
router.get('/me', auth, async (req, res) => {
  try {
    const driver = await Driver.findById(req.driver.id);
    
    if (!driver) {
      return res.status(404).json({ msg: 'Driver not found' });
    }
    
    // Don't send password to client
    delete driver.password;
    
    res.json(driver);
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server error');
  }
});

// @route   PUT api/drivers/status
// @desc    Update driver availability status
// @access  Private
router.put('/status', auth, async (req, res) => {
  const { isAvailable } = req.body;
  
  try {
    const driver = await Driver.update(req.driver.id, {
      is_available: isAvailable
    });
    
    if (!driver) {
      return res.status(404).json({ msg: 'Driver not found' });
    }
    
    res.json(driver);
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server error');
  }
});

// @route   PUT api/drivers/location
// @desc    Update driver location
// @access  Private
router.put('/location', auth, async (req, res) => {
  const { lat, lng } = req.body;
  
  try {
    const driver = await Driver.update(req.driver.id, {
      current_location: { lat, lng }
    });
    
    if (!driver) {
      return res.status(404).json({ msg: 'Driver not found' });
    }
    
    res.json(driver);
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server error');
  }
});

// @route   PUT api/drivers/profile
// @desc    Update driver profile
// @access  Private
router.put('/profile', auth, async (req, res) => {
  const { name, phone, vehicleDetails } = req.body;
  
  try {
    const updateData = {};
    if (name) updateData.name = name;
    if (phone) updateData.phone = phone;
    if (vehicleDetails) updateData.vehicle_details = vehicleDetails;
    
    const driver = await Driver.update(req.driver.id, updateData);
    
    if (!driver) {
      return res.status(404).json({ msg: 'Driver not found' });
    }
    
    res.json(driver);
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server error');
  }
});

module.exports = router; 