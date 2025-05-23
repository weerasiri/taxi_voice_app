// Main application logic
document.addEventListener('DOMContentLoaded', initApp);

// Socket.io connection
let socket;

// Current driver data
let currentDriver = null;

// Initialize the application
async function initApp() {
  try {
    // Check if user is authenticated
    if (isAuthenticated()) {
      // Load user profile
      currentDriver = await loadUserProfile();
      
      if (currentDriver) {
        // Initialize socket connection
        initializeSocket();
        
        // Render authenticated navigation
        renderAuthenticatedNav();
        
        // Render dashboard
        renderDashboard();
      } else {
        // Render login page
        renderLoginPage();
      }
    } else {
      // Render login page
      renderLoginPage();
    }
  } catch (error) {
    console.error('Error initializing app:', error);
    showAlert('An error occurred while loading the application.', 'danger');
  }
}

// Initialize Socket.io connection
function initializeSocket() {
  const socketUrl = window.location.hostname === 'localhost' ? 'http://localhost:5000' : '';
  
  socket = io(socketUrl);
  
  // Socket event listeners
  socket.on('connect', () => {
    console.log('Socket connected');
  });
  
  socket.on('rideRequest', (rideData) => {
    // Show notification for new ride request
    showNotification('New Ride Request', 'You have a new ride request!');
    
    // Update the ride list if on dashboard
    if (document.getElementById('ride-requests-container')) {
      fetchAndRenderRideRequests();
    }
  });
  
  socket.on('rideAccepted', (data) => {
    // If this driver accepted the ride, update UI
    if (data.driverId === currentDriver._id) {
      showAlert('Ride accepted successfully!', 'success');
      fetchAndRenderRideRequests();
    }
  });
  
  socket.on('rideDeclined', (data) => {
    // Update UI if needed
    fetchAndRenderRideRequests();
  });
  
  socket.on('disconnect', () => {
    console.log('Socket disconnected');
  });
}

// Render authenticated navigation
function renderAuthenticatedNav() {
  const navItems = document.getElementById('nav-items');
  
  navItems.innerHTML = `
    <li class="nav-item">
      <a class="nav-link active" href="#" id="nav-dashboard">Dashboard</a>
    </li>
    <li class="nav-item">
      <a class="nav-link" href="#" id="nav-profile">My Profile</a>
    </li>
    <li class="nav-item">
      <a class="nav-link" href="#" id="nav-rides">My Rides</a>
    </li>
    <li class="nav-item">
      <a class="nav-link" href="#" id="nav-logout">Logout</a>
    </li>
  `;
  
  // Add event listeners
  document.getElementById('nav-dashboard').addEventListener('click', renderDashboard);
  document.getElementById('nav-profile').addEventListener('click', renderProfilePage);
  document.getElementById('nav-rides').addEventListener('click', renderRidesPage);
  document.getElementById('nav-logout').addEventListener('click', logout);
}

// Render login page
function renderLoginPage() {
  const mainContent = document.getElementById('main-content');
  
  // Update navigation
  const navItems = document.getElementById('nav-items');
  navItems.innerHTML = `
    <li class="nav-item">
      <a class="nav-link active" href="#" id="nav-login">Login</a>
    </li>
    <li class="nav-item">
      <a class="nav-link" href="#" id="nav-register">Register</a>
    </li>
  `;
  
  // Render login form
  mainContent.innerHTML = `
    <div class="card login-form">
      <div class="card-header bg-dark text-white">
        <h4>Driver Login</h4>
      </div>
      <div class="card-body">
        <div id="login-alert"></div>
        <form id="login-form">
          <div class="mb-3">
            <label for="email" class="form-label">Email Address</label>
            <input type="email" class="form-control" id="email" required>
          </div>
          <div class="mb-3">
            <label for="password" class="form-label">Password</label>
            <input type="password" class="form-control" id="password" required>
          </div>
          <button type="submit" class="btn btn-primary w-100">Login</button>
        </form>
        <p class="mt-3 text-center">
          Don't have an account? <a href="#" id="goto-register">Register here</a>
        </p>
      </div>
    </div>
  `;
  
  // Add event listeners
  document.getElementById('login-form').addEventListener('submit', handleLogin);
  document.getElementById('goto-register').addEventListener('click', renderRegisterPage);
  document.getElementById('nav-login').addEventListener('click', renderLoginPage);
  document.getElementById('nav-register').addEventListener('click', renderRegisterPage);
}

// Handle login form submission
async function handleLogin(e) {
  e.preventDefault();
  
  const email = document.getElementById('email').value;
  const password = document.getElementById('password').value;
  
  try {
    const response = await AuthAPI.login(email, password);
    
    // Store token
    setAuth(response.token, null);
    
    // Load user profile
    currentDriver = await loadUserProfile();
    
    // Initialize socket connection
    initializeSocket();
    
    // Render authenticated nav and dashboard
    renderAuthenticatedNav();
    renderDashboard();
    
    showAlert('Login successful!', 'success');
  } catch (error) {
    showAlert(error.message || 'Login failed. Please check your credentials.', 'danger', 'login-alert');
  }
}

// Render register page
function renderRegisterPage() {
  const mainContent = document.getElementById('main-content');
  
  // Update navigation active state
  document.getElementById('nav-login').classList.remove('active');
  document.getElementById('nav-register').classList.add('active');
  
  // Render register form
  mainContent.innerHTML = `
    <div class="card register-form">
      <div class="card-header bg-dark text-white">
        <h4>Driver Registration</h4>
      </div>
      <div class="card-body">
        <div id="register-alert"></div>
        <form id="register-form">
          <div class="mb-3">
            <label for="reg-name" class="form-label">Full Name</label>
            <input type="text" class="form-control" id="reg-name" required>
          </div>
          <div class="mb-3">
            <label for="reg-email" class="form-label">Email Address</label>
            <input type="email" class="form-control" id="reg-email" required>
          </div>
          <div class="mb-3">
            <label for="reg-password" class="form-label">Password</label>
            <input type="password" class="form-control" id="reg-password" required>
          </div>
          <div class="mb-3">
            <label for="reg-phone" class="form-label">Phone Number</label>
            <input type="tel" class="form-control" id="reg-phone" required>
          </div>
          <div class="mb-3">
            <label for="reg-license" class="form-label">Driver License Number</label>
            <input type="text" class="form-control" id="reg-license" required>
          </div>
          <div class="mb-3">
            <label class="form-label">Vehicle Details</label>
            <div class="row g-2">
              <div class="col-md-4">
                <input type="text" class="form-control" id="vehicle-model" placeholder="Model" required>
              </div>
              <div class="col-md-4">
                <input type="text" class="form-control" id="vehicle-color" placeholder="Color" required>
              </div>
              <div class="col-md-4">
                <input type="text" class="form-control" id="vehicle-plate" placeholder="Plate Number" required>
              </div>
            </div>
          </div>
          <button type="submit" class="btn btn-primary w-100">Register</button>
        </form>
        <p class="mt-3 text-center">
          Already have an account? <a href="#" id="goto-login">Login here</a>
        </p>
      </div>
    </div>
  `;
  
  // Add event listeners
  document.getElementById('register-form').addEventListener('submit', handleRegister);
  document.getElementById('goto-login').addEventListener('click', renderLoginPage);
}

// Handle register form submission
async function handleRegister(e) {
  e.preventDefault();
  
  const name = document.getElementById('reg-name').value;
  const email = document.getElementById('reg-email').value;
  const password = document.getElementById('reg-password').value;
  const phone = document.getElementById('reg-phone').value;
  const licenseNumber = document.getElementById('reg-license').value;
  const vehicleModel = document.getElementById('vehicle-model').value;
  const vehicleColor = document.getElementById('vehicle-color').value;
  const vehiclePlate = document.getElementById('vehicle-plate').value;
  
  const vehicleDetails = {
    model: vehicleModel,
    color: vehicleColor,
    plateNumber: vehiclePlate
  };
  
  try {
    const response = await AuthAPI.register({
      name,
      email,
      password,
      phone,
      licenseNumber,
      vehicleDetails
    });
    
    // Store token
    setAuth(response.token, null);
    
    // Load user profile
    currentDriver = await loadUserProfile();
    
    // Initialize socket connection
    initializeSocket();
    
    // Render authenticated nav and dashboard
    renderAuthenticatedNav();
    renderDashboard();
    
    showAlert('Registration successful!', 'success');
  } catch (error) {
    showAlert(error.message || 'Registration failed. Please try again.', 'danger', 'register-alert');
  }
}

// Render dashboard page
async function renderDashboard() {
  const mainContent = document.getElementById('main-content');
  
  // Update navigation active state
  const navLinks = document.querySelectorAll('.nav-link');
  navLinks.forEach(link => link.classList.remove('active'));
  document.getElementById('nav-dashboard').classList.add('active');
  
  // Show loading
  mainContent.innerHTML = `
    <div class="loading-spinner">
      <div class="spinner-border text-warning" role="status">
        <span class="visually-hidden">Loading...</span>
      </div>
    </div>
  `;
  
  try {
    // Fetch ride requests
    const rideRequests = await RideAPI.getAvailableRides(getToken());
    
    // Render dashboard
    mainContent.innerHTML = `
      <div class="row mb-4">
        <div class="col-md-12">
          <div class="card">
            <div class="card-header bg-gold">
              <h4>Driver Dashboard</h4>
            </div>
            <div class="card-body">
              <div class="d-flex justify-content-between align-items-center mb-4">
                <h5>Welcome, ${currentDriver.name}</h5>
                <div class="driver-status d-flex align-items-center">
                  <span class="me-2">Available for rides:</span>
                  <label class="toggle-switch">
                    <input type="checkbox" id="status-toggle" ${currentDriver.isAvailable ? 'checked' : ''}>
                    <span class="slider"></span>
                  </label>
                </div>
              </div>
              
              <div class="dashboard-stats">
                <div class="stat-card">
                  <div class="icon">
                    <i class="fas fa-car"></i>
                  </div>
                  <div class="count">${currentDriver.totalRides}</div>
                  <div class="label">Total Rides</div>
                </div>
                
                <div class="stat-card">
                  <div class="icon">
                    <i class="fas fa-star"></i>
                  </div>
                  <div class="count">${currentDriver.rating || 'N/A'}</div>
                  <div class="label">Rating</div>
                </div>
                
                <div class="stat-card">
                  <div class="icon">
                    <i class="fas fa-map-marker-alt"></i>
                  </div>
                  <div class="count">
                    <button class="btn btn-sm btn-outline-warning" id="update-location-btn">
                      Update
                    </button>
                  </div>
                  <div class="label">Current Location</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      
      <div class="row">
        <div class="col-md-12">
          <div class="card">
            <div class="card-header bg-dark text-white d-flex justify-content-between align-items-center">
              <h5 class="mb-0">Available Ride Requests</h5>
              <button class="btn btn-sm btn-warning" id="refresh-rides-btn">
                <i class="fas fa-sync-alt"></i> Refresh
              </button>
            </div>
            <div class="card-body">
              <div id="ride-requests-container">
                ${renderRideRequestsList(rideRequests)}
              </div>
            </div>
          </div>
        </div>
      </div>
    `;
    
    // Add event listeners
    document.getElementById('status-toggle').addEventListener('change', handleStatusToggle);
    document.getElementById('update-location-btn').addEventListener('click', handleUpdateLocation);
    document.getElementById('refresh-rides-btn').addEventListener('click', fetchAndRenderRideRequests);
    
    // Add event listeners to accept/decline buttons
    const acceptButtons = document.querySelectorAll('.accept-ride-btn');
    const declineButtons = document.querySelectorAll('.decline-ride-btn');
    
    acceptButtons.forEach(button => {
      button.addEventListener('click', () => handleAcceptRide(button.dataset.rideId));
    });
    
    declineButtons.forEach(button => {
      button.addEventListener('click', () => handleDeclineRide(button.dataset.rideId));
    });
  } catch (error) {
    mainContent.innerHTML = `
      <div class="alert alert-danger">
        Error loading dashboard: ${error.message || 'An error occurred'}
      </div>
    `;
  }
}

// Render ride requests list
function renderRideRequestsList(rides) {
  if (!rides || rides.length === 0) {
    return `
      <div class="text-center py-4">
        <i class="fas fa-info-circle text-warning mb-3" style="font-size: 3rem;"></i>
        <p class="mb-0">No ride requests available at the moment.</p>
      </div>
    `;
  }
  
  // Helper function to safely get nested properties
  const getSafe = (obj, path, fallback = '') => {
    try {
      return path.split('.').reduce((o, key) => o[key], obj) || fallback;
    } catch (e) {
      return fallback;
    }
  };
  
  return rides.map(ride => {
    // Handle both MongoDB and Supabase formatted data
    const rideId = ride.id || ride._id;
    const requestTime = ride.request_time || ride.requestTime;
    
    // Handle pickup location
    let pickupAddress = 'Unknown location';
    if (typeof ride.pickup === 'object' && ride.pickup) {
      pickupAddress = ride.pickup.address || 'Unknown location';
    } else if (ride.pickup_location) {
      pickupAddress = ride.pickup_location;
    }
    
    // Handle destination
    let destinationAddress = 'Unknown destination';
    if (typeof ride.destination === 'object' && ride.destination) {
      destinationAddress = ride.destination.address || 'Unknown destination';
    }
    
    return `
      <div class="ride-request">
        <div class="row">
          <div class="col-md-8">
            <div class="d-flex mb-2">
              <span class="status-badge status-requested me-2">Requested</span>
              <span class="text-muted">${new Date(requestTime).toLocaleString()}</span>
            </div>
            <h5>Pickup: ${pickupAddress}</h5>
            <h5>Destination: ${destinationAddress}</h5>
            <p class="mb-0">
              <strong>Passenger:</strong> ${ride.user_name || 'Anonymous'}
              <br>
              <strong>Phone:</strong> ${ride.user_phone || 'Not provided'}
            </p>
          </div>
          <div class="col-md-4">
            <div class="ride-actions d-flex flex-column h-100 justify-content-center">
              <button class="btn btn-success mb-2 accept-ride-btn" data-ride-id="${rideId}">
                <i class="fas fa-check"></i> Accept
              </button>
              <button class="btn btn-outline-danger decline-ride-btn" data-ride-id="${rideId}">
                <i class="fas fa-times"></i> Decline
              </button>
            </div>
          </div>
        </div>
      </div>
    `;
  }).join('');
}

// Fetch and render ride requests
async function fetchAndRenderRideRequests() {
  const container = document.getElementById('ride-requests-container');
  
  if (!container) return;
  
  container.innerHTML = `
    <div class="text-center py-4">
      <div class="spinner-border text-warning" role="status">
        <span class="visually-hidden">Loading...</span>
      </div>
    </div>
  `;
  
  try {
    const rideRequests = await RideAPI.getAvailableRides(getToken());
    container.innerHTML = renderRideRequestsList(rideRequests);
    
    // Re-add event listeners
    const acceptButtons = document.querySelectorAll('.accept-ride-btn');
    const declineButtons = document.querySelectorAll('.decline-ride-btn');
    
    acceptButtons.forEach(button => {
      button.addEventListener('click', () => handleAcceptRide(button.dataset.rideId));
    });
    
    declineButtons.forEach(button => {
      button.addEventListener('click', () => handleDeclineRide(button.dataset.rideId));
    });
  } catch (error) {
    container.innerHTML = `
      <div class="alert alert-danger">
        Error loading ride requests: ${error.message || 'An error occurred'}
      </div>
    `;
  }
}

// Handle driver status toggle
async function handleStatusToggle(e) {
  const isAvailable = e.target.checked;
  
  try {
    await DriverAPI.updateStatus(isAvailable, getToken());
    currentDriver.isAvailable = isAvailable;
    showAlert(`You are now ${isAvailable ? 'available' : 'unavailable'} for rides.`, 'success');
  } catch (error) {
    e.target.checked = !isAvailable; // Revert toggle
    showAlert('Failed to update status. Please try again.', 'danger');
  }
}

// Handle update location
async function handleUpdateLocation() {
  // Show loading indicator
  const locationBtn = document.getElementById('update-location-btn');
  locationBtn.innerHTML = '<span class="spinner-border spinner-border-sm"></span>';
  locationBtn.disabled = true;
  
  try {
    // Get current position
    navigator.geolocation.getCurrentPosition(
      async (position) => {
        const { latitude, longitude } = position.coords;
        
        try {
          await DriverAPI.updateLocation(latitude, longitude, getToken());
          currentDriver.currentLocation = { lat: latitude, lng: longitude };
          showAlert('Location updated successfully!', 'success');
        } catch (error) {
          showAlert('Failed to update location. Please try again.', 'danger');
        } finally {
          locationBtn.innerHTML = 'Update';
          locationBtn.disabled = false;
        }
      },
      (error) => {
        showAlert('Failed to get location. Please check your device settings.', 'danger');
        locationBtn.innerHTML = 'Update';
        locationBtn.disabled = false;
      }
    );
  } catch (error) {
    showAlert('Failed to update location. Please try again.', 'danger');
    locationBtn.innerHTML = 'Update';
    locationBtn.disabled = false;
  }
}

// Handle accept ride
async function handleAcceptRide(rideId) {
  try {
    console.log('Accepting ride with ID:', rideId);
    
    // Show loading indicator
    const acceptBtn = document.querySelector(`.accept-ride-btn[data-ride-id="${rideId}"]`);
    if (acceptBtn) {
      const originalText = acceptBtn.innerHTML;
      acceptBtn.innerHTML = '<span class="spinner-border spinner-border-sm"></span>';
      acceptBtn.disabled = true;
    }
    
    const acceptedRide = await RideAPI.acceptRide(rideId, getToken());
    
    // Emit event to server - make sure to use the UUID format of the ID
    socket.emit('acceptRide', {
      rideId: acceptedRide.id || acceptedRide._id, 
      driverId: currentDriver.id || currentDriver._id,
      driverName: currentDriver.name,
      vehicleDetails: currentDriver.vehicleDetails
    });
    
    // Update UI
    showAlert('Ride accepted successfully!', 'success');
    fetchAndRenderRideRequests();
    
    // Navigate to active rides tab
    setTimeout(() => {
      renderRidesPage();
    }, 2000);
  } catch (error) {
    console.error('Error accepting ride:', error);
    showAlert(error.message || 'Failed to accept ride. Please try again.', 'danger');
    
    // Re-enable button
    const acceptBtn = document.querySelector(`.accept-ride-btn[data-ride-id="${rideId}"]`);
    if (acceptBtn) {
      acceptBtn.innerHTML = '<i class="fas fa-check"></i> Accept';
      acceptBtn.disabled = false;
    }
  }
}

// Handle decline ride
async function handleDeclineRide(rideId) {
  try {
    const declinedRide = await RideAPI.declineRide(rideId, getToken());
    
    // Emit event to server
    socket.emit('declineRide', {
      rideId: declinedRide._id
    });
    
    // Update UI
    showAlert('Ride declined.', 'info');
    fetchAndRenderRideRequests();
  } catch (error) {
    showAlert(error.message || 'Failed to decline ride. Please try again.', 'danger');
  }
}

// Render profile page
function renderProfilePage() {
  const mainContent = document.getElementById('main-content');
  
  // Update navigation active state
  const navLinks = document.querySelectorAll('.nav-link');
  navLinks.forEach(link => link.classList.remove('active'));
  document.getElementById('nav-profile').classList.add('active');
  
  // Render profile page
  mainContent.innerHTML = `
    <div class="card">
      <div class="card-header bg-gold">
        <h4>My Profile</h4>
      </div>
      <div class="card-body">
        <div id="profile-alert"></div>
        <form id="profile-form">
          <div class="mb-3">
            <label for="profile-name" class="form-label">Full Name</label>
            <input type="text" class="form-control" id="profile-name" value="${currentDriver.name}" required>
          </div>
          <div class="mb-3">
            <label for="profile-email" class="form-label">Email Address</label>
            <input type="email" class="form-control" id="profile-email" value="${currentDriver.email}" disabled>
            <div class="form-text">Email address cannot be changed.</div>
          </div>
          <div class="mb-3">
            <label for="profile-phone" class="form-label">Phone Number</label>
            <input type="tel" class="form-control" id="profile-phone" value="${currentDriver.phone}" required>
          </div>
          <div class="mb-3">
            <label for="profile-license" class="form-label">Driver License Number</label>
            <input type="text" class="form-control" id="profile-license" value="${currentDriver.licenseNumber}" disabled>
            <div class="form-text">License number cannot be changed.</div>
          </div>
          <div class="mb-3">
            <label class="form-label">Vehicle Details</label>
            <div class="row g-2">
              <div class="col-md-4">
                <input type="text" class="form-control" id="profile-vehicle-model" placeholder="Model" value="${currentDriver.vehicleDetails?.model || ''}" required>
              </div>
              <div class="col-md-4">
                <input type="text" class="form-control" id="profile-vehicle-color" placeholder="Color" value="${currentDriver.vehicleDetails?.color || ''}" required>
              </div>
              <div class="col-md-4">
                <input type="text" class="form-control" id="profile-vehicle-plate" placeholder="Plate Number" value="${currentDriver.vehicleDetails?.plateNumber || ''}" required>
              </div>
            </div>
          </div>
          <button type="submit" class="btn btn-primary">Update Profile</button>
        </form>
      </div>
    </div>
  `;
  
  // Add event listener
  document.getElementById('profile-form').addEventListener('submit', handleProfileUpdate);
}

// Handle profile update
async function handleProfileUpdate(e) {
  e.preventDefault();
  
  const name = document.getElementById('profile-name').value;
  const phone = document.getElementById('profile-phone').value;
  const vehicleModel = document.getElementById('profile-vehicle-model').value;
  const vehicleColor = document.getElementById('profile-vehicle-color').value;
  const vehiclePlate = document.getElementById('profile-vehicle-plate').value;
  
  const vehicleDetails = {
    model: vehicleModel,
    color: vehicleColor,
    plateNumber: vehiclePlate
  };
  
  try {
    const updatedProfile = await DriverAPI.updateProfile({
      name,
      phone,
      vehicleDetails
    }, getToken());
    
    // Update current driver
    currentDriver = updatedProfile;
    
    showAlert('Profile updated successfully!', 'success', 'profile-alert');
  } catch (error) {
    showAlert(error.message || 'Failed to update profile. Please try again.', 'danger', 'profile-alert');
  }
}

// Render rides page
async function renderRidesPage() {
  const mainContent = document.getElementById('main-content');
  
  // Update navigation active state
  const navLinks = document.querySelectorAll('.nav-link');
  navLinks.forEach(link => link.classList.remove('active'));
  document.getElementById('nav-rides').classList.add('active');
  
  // Show loading
  mainContent.innerHTML = `
    <div class="loading-spinner">
      <div class="spinner-border text-warning" role="status">
        <span class="visually-hidden">Loading...</span>
      </div>
    </div>
  `;
  
  try {
    // Fetch driver's rides
    const rides = await RideAPI.getDriverRides(getToken());
    
    // Render rides page
    mainContent.innerHTML = `
      <div class="card">
        <div class="card-header bg-gold">
          <h4>My Rides</h4>
        </div>
        <div class="card-body">
          <div class="mb-4">
            <ul class="nav nav-pills" id="rides-tab">
              <li class="nav-item">
                <a class="nav-link active" id="active-rides-tab" data-bs-toggle="pill" href="#active-rides">Active</a>
              </li>
              <li class="nav-item">
                <a class="nav-link" id="completed-rides-tab" data-bs-toggle="pill" href="#completed-rides">Completed</a>
              </li>
            </ul>
          </div>
          
          <div class="tab-content">
            <div class="tab-pane fade show active" id="active-rides">
              ${renderRidesList(rides.filter(ride => ride.status === 'accepted'), true)}
            </div>
            <div class="tab-pane fade" id="completed-rides">
              ${renderRidesList(rides.filter(ride => ride.status === 'completed'), false)}
            </div>
          </div>
        </div>
      </div>
    `;
    
    // Add event listeners to complete buttons
    const completeButtons = document.querySelectorAll('.complete-ride-btn');
    
    completeButtons.forEach(button => {
      button.addEventListener('click', () => handleCompleteRide(button.dataset.rideId));
    });
  } catch (error) {
    mainContent.innerHTML = `
      <div class="alert alert-danger">
        Error loading rides: ${error.message || 'An error occurred'}
      </div>
    `;
  }
}

// Render rides list
function renderRidesList(rides, isActive) {
  if (!rides || rides.length === 0) {
    return `
      <div class="text-center py-4">
        <i class="fas fa-info-circle text-warning mb-3" style="font-size: 3rem;"></i>
        <p class="mb-0">No ${isActive ? 'active' : 'completed'} rides to display.</p>
      </div>
    `;
  }
  
  return rides.map(ride => `
    <div class="ride-request">
      <div class="row">
        <div class="col-md-8">
          <div class="d-flex mb-2">
            <span class="status-badge ${isActive ? 'status-accepted' : 'status-completed'} me-2">
              ${isActive ? 'Active' : 'Completed'}
            </span>
            <span class="text-muted">
              ${isActive ? new Date(ride.requestTime).toLocaleString() : new Date(ride.completionTime).toLocaleString()}
            </span>
          </div>
          <h5>Pickup: ${ride.pickup.address}</h5>
          <h5>Destination: ${ride.destination.address}</h5>
          <p class="mb-0">
            <strong>Fare:</strong> $${ride.fare || 'To be calculated'}
            <br>
            <strong>Payment Method:</strong> ${ride.paymentMethod}
          </p>
        </div>
        <div class="col-md-4">
          <div class="ride-actions d-flex flex-column h-100 justify-content-center">
            ${isActive ? `
              <button class="btn btn-success complete-ride-btn" data-ride-id="${ride._id}">
                <i class="fas fa-flag-checkered"></i> Complete Ride
              </button>
            ` : `
              <div class="text-center">
                ${ride.rating ? `
                  <div class="mb-2">
                    <strong>Rating:</strong> ${ride.rating} <i class="fas fa-star text-warning"></i>
                  </div>
                ` : ''}
                <div>
                  <strong>Feedback:</strong> ${ride.feedback || 'No feedback provided'}
                </div>
              </div>
            `}
          </div>
        </div>
      </div>
    </div>
  `).join('');
}

// Handle complete ride
async function handleCompleteRide(rideId) {
  try {
    const completedRide = await RideAPI.completeRide(rideId, getToken());
    
    // Update UI
    showAlert('Ride completed successfully!', 'success');
    renderRidesPage();
  } catch (error) {
    showAlert(error.message || 'Failed to complete ride. Please try again.', 'danger');
  }
}

// Show alert message
function showAlert(message, type = 'info', containerId = null) {
  const alert = document.createElement('div');
  alert.className = `alert alert-${type} alert-dismissible fade show`;
  alert.innerHTML = `
    ${message}
    <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
  `;
  
  if (containerId) {
    const container = document.getElementById(containerId);
    if (container) {
      container.innerHTML = '';
      container.appendChild(alert);
    }
  } else {
    const mainContent = document.getElementById('main-content');
    mainContent.insertAdjacentElement('afterbegin', alert);
  }
  
  // Auto-dismiss after 5 seconds
  setTimeout(() => {
    alert.classList.remove('show');
    setTimeout(() => {
      alert.remove();
    }, 500);
  }, 5000);
}

// Show browser notification
function showNotification(title, body) {
  // Check if browser supports notifications
  if (!("Notification" in window)) {
    console.log("This browser does not support desktop notification");
    return;
  }
  
  // Check if permission is granted
  if (Notification.permission === "granted") {
    const notification = new Notification(title, {
      body,
      icon: '/img/logo.png'
    });
    
    notification.onclick = function() {
      window.focus();
      this.close();
    };
  } else if (Notification.permission !== "denied") {
    // Request permission
    Notification.requestPermission().then(permission => {
      if (permission === "granted") {
        const notification = new Notification(title, {
          body,
          icon: '/img/logo.png'
        });
        
        notification.onclick = function() {
          window.focus();
          this.close();
        };
      }
    });
  }
}