// Authentication related functions
const TOKEN_KEY = 'driver_token';
const USER_KEY = 'driver_user';

// Function to store token and user in local storage
function setAuth(token, user) {
  localStorage.setItem(TOKEN_KEY, token);
  localStorage.setItem(USER_KEY, JSON.stringify(user));
}

// Function to get token from local storage
function getToken() {
  return localStorage.getItem(TOKEN_KEY);
}

// Function to get user from local storage
function getUser() {
  const user = localStorage.getItem(USER_KEY);
  return user ? JSON.parse(user) : null;
}

// Function to check if user is authenticated
function isAuthenticated() {
  return !!getToken();
}

// Function to logout user
function logout() {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(USER_KEY);
  window.location.href = '/';
}

// Function to load user profile
async function loadUserProfile() {
  try {
    const token = getToken();
    if (!token) return null;

    const user = await AuthAPI.getProfile(token);
    setAuth(token, user);
    return user;
  } catch (error) {
    console.error('Error loading user profile:', error);
    logout();
    return null;
  }
} 