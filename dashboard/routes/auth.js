const express = require('express');
const router = express.Router();
const { check, validationResult } = require('express-validator');
const jwt = require('jsonwebtoken');
const Driver = require('../models/Driver');

// @route   POST api/auth/register
// @desc    Register a driver
// @access  Public
router.post('/register', [
  check('name', 'Name is required').not().isEmpty(),
  check('email', 'Please include a valid email').isEmail(),
  check('password', 'Password is required').exists()
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  const { 
    name, 
    email, 
    password, 
    phone = '123-456-7890', // Default value
    licenseNumber = 'DL-123456', // Default value
    vehicleDetails = { // Default values
      model: 'Default Car',
      color: 'Black',
      plateNumber: 'ABC-1234'
    } 
  } = req.body;

  try {
    // Check if driver already exists
    const existingDriver = await Driver.findByEmail(email);
    if (existingDriver) {
      return res.status(400).json({ msg: 'Driver already exists' });
    }

    // Create new driver
    const driver = await Driver.create({
      name,
      email,
      password,
      phone,
      licenseNumber,
      vehicleDetails
    });

    // Create JWT
    const payload = {
      driver: {
        id: driver.id
      }
    };

    const JWT_SECRET = process.env.JWT_SECRET || 'default_development_secret_key';
    jwt.sign(
      payload,
      JWT_SECRET,
      { expiresIn: 360000 },
      (err, token) => {
        if (err) throw err;
        res.json({ token, driver: { ...driver, password: undefined } });
      }
    );
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server error');
  }
});

// @route   POST api/auth/login
// @desc    Authenticate driver & get token
// @access  Public
router.post('/login', [
  check('email', 'Please include a valid email').isEmail(),
  check('password', 'Password is required').exists()
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  const { email, password } = req.body;

  try {
    // Check if driver exists
    const driver = await Driver.findByEmail(email);
    if (!driver) {
      return res.status(400).json({ msg: 'Invalid credentials' });
    }

    // Compare password
    const isMatch = await Driver.comparePassword(password, driver.password);
    if (!isMatch) {
      return res.status(400).json({ msg: 'Invalid credentials' });
    }

    // Create JWT
    const payload = {
      driver: {
        id: driver.id
      }
    };

    const JWT_SECRET = process.env.JWT_SECRET || 'default_development_secret_key';
    jwt.sign(
      payload,
      JWT_SECRET,
      { expiresIn: 360000 },
      (err, token) => {
        if (err) throw err;
        res.json({ token, driver: { ...driver, password: undefined } });
      }
    );
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server error');
  }
});

// @route   GET api/auth/test
// @desc    Test route
// @access  Public
router.get('/test', (req, res) => {
  res.json({ msg: 'Auth route working' });
});

module.exports = router; 