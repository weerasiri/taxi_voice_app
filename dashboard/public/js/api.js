// API utility functions
const API_URL = window.location.hostname === 'localhost' ? 'http://localhost:5000/api' : '/api';

// Function to make API requests
async function apiRequest(endpoint, method = 'GET', body = null, token = null) {
  const headers = {
    'Content-Type': 'application/json'
  };

  if (token) {
    headers['x-auth-token'] = token;
  }

  const config = {
    method,
    headers
  };

  if (body) {
    config.body = JSON.stringify(body);
  }

  try {
    const response = await fetch(`${API_URL}${endpoint}`, config);
    const data = await response.json();
    
    if (!response.ok) {
      throw new Error(data.msg || 'Something went wrong');
    }
    
    return data;
  } catch (error) {
    throw error;
  }
}

// Authentication API calls
const AuthAPI = {
  // Register a new driver
  register: (driverData) => {
    return apiRequest('/auth/register', 'POST', driverData);
  },
  
  // Login a driver
  login: (email, password) => {
    return apiRequest('/auth/login', 'POST', { email, password });
  },
  
  // Get current driver profile
  getProfile: (token) => {
    return apiRequest('/drivers/me', 'GET', null, token);
  }
};

// Driver API calls
const DriverAPI = {
  // Update driver availability status
  updateStatus: (isAvailable, token) => {
    return apiRequest('/drivers/status', 'PUT', { isAvailable }, token);
  },
  
  // Update driver location
  updateLocation: (lat, lng, token) => {
    return apiRequest('/drivers/location', 'PUT', { lat, lng }, token);
  },
  
  // Update driver profile
  updateProfile: (profileData, token) => {
    return apiRequest('/drivers/profile', 'PUT', profileData, token);
  }
};

// Ride API calls
const RideAPI = {
  // Get all available ride requests
  getAvailableRides: (token) => {
    return apiRequest('/rides', 'GET', null, token);
  },
  
  // Get driver's rides
  getDriverRides: (token) => {
    return apiRequest('/rides/driver', 'GET', null, token);
  },
  
  // Accept a ride
  acceptRide: (rideId, token) => {
    return apiRequest(`/rides/${rideId}/accept`, 'PUT', null, token);
  },
  
  // Decline a ride
  declineRide: (rideId, token) => {
    return apiRequest(`/rides/${rideId}/decline`, 'PUT', null, token);
  },
  
  // Complete a ride
  completeRide: (rideId, token) => {
    return apiRequest(`/rides/${rideId}/complete`, 'PUT', null, token);
  }
}; 