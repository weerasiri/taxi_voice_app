# TaxiVoice Driver Dashboard

A web-based dashboard for drivers to manage ride requests and their driving status.

## Features

- Real-time ride request notifications
- Accept/decline ride requests
- Manage driver availability status
- Track completed rides
- Integration with Supabase for data persistence
- Real-time communication using Socket.io

## Tech Stack

- Node.js and Express for the backend
- Socket.io for real-time communication
- Supabase for database storage
- Bootstrap and vanilla JavaScript for the frontend
- JWT authentication for driver security

## Setup Instructions

### Prerequisites

- Node.js (v14+)
- A Supabase account and project

### Environment Variables

Create a `.env` file in the root directory with the following variables:

```
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_KEY=your-supabase-anon-key
JWT_SECRET=your-secret-key-for-jwt
PORT=5000
```

You can also check the `env-setup.txt` file for more information.

### Installation

1. Clone the repository
2. Install dependencies:

```bash
cd dashboard
npm install
```

3. Start the server:

```bash
npm start
```

Or for development with auto-restart:

```bash
npm run dev
```

4. Access the dashboard at http://localhost:5000

## For PowerShell Users

To start the server in PowerShell, use:

```powershell
cd dashboard
node server.js
```

## API Endpoints

- **GET /api/rides**: Get all available ride requests
- **PUT /api/rides/:id/accept**: Accept a ride
- **PUT /api/rides/:id/decline**: Decline a ride
- **PUT /api/rides/:id/complete**: Complete a ride
- **GET /api/drivers/me**: Get current driver profile
- **PUT /api/drivers/status**: Update driver status

## Socket.io Events

- **newRideRequest**: Emitted when a new ride request is created
- **rideAccepted**: Emitted when a driver accepts a ride
- **rideDeclined**: Emitted when a driver declines a ride
- **driverStatusUpdated**: Emitted when a driver changes availability

## Database Schema

The dashboard works with a Supabase database with the following tables:

- **drivers**: Driver information and status
- **rides**: Ride requests and details
- **users**: Passenger information

## Troubleshooting

- If rides are not showing up in the dashboard, check the Supabase connection and ensure rides are being properly created.
- If ride acceptance is failing, verify that the Supabase API key has proper permissions.
- For Socket.io communication issues, check that the frontend URL matches the backend setup. 