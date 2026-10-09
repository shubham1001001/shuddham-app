// ─────────────────────────────────────────────────────────────────────────────
// Shuddham Water Solutions — Centralized API Endpoints Registry
// ─────────────────────────────────────────────────────────────────────────────
//
// All backend API endpoints used across the app in one place.
// Base URL is configured in [AppConstants] (app_constants.dart).
//
// Backend Base: https://shuddham-backend.onrender.com/api
// ─────────────────────────────────────────────────────────────────────────────

class ApiEndpoints {
  ApiEndpoints._(); // prevent instantiation

  // ═══════════════════════════════════════════════════════════════════════════
  // 🌐 BASE URL — Live AWS Production Backend Server (Same as Admin Panel)
  // ═══════════════════════════════════════════════════════════════════════════
  /// Live production backend hosted on AWS EC2
  static const String liveBaseUrl = 'http://3.88.13.76:4000/api';

  /// Primary base URL used across the application
  static const String baseUrl = liveBaseUrl;

  /// Dedicated single production URL (no fallbacks)
  static const List<String> allBaseUrls = [
    liveBaseUrl,
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔐 AUTH — Customer Authentication (Mobile App)
  // ═══════════════════════════════════════════════════════════════════════════
  /// POST — Customer sign in with phone/email + password
  static const String customerLogin = '/auth/customer/login';

  /// POST — Customer sign up (new account creation)
  static const String customerSignup = '/auth/customer/signup';

  /// POST — Universal login alias (fallback)
  static const String login = '/auth/login';

  /// POST — Universal signup alias (fallback)
  static const String signup = '/auth/signup';

  /// POST — Send OTP to phone number
  static const String sendOtp = '/auth/send-otp';

  /// POST — Verify OTP code
  static const String verifyOtp = '/auth/verify-otp';

  /// POST — Forgot password (reset instructions)
  static const String forgotPassword = '/auth/forgot-password';

  /// POST — Logout (invalidate session token)
  static const String logout = '/auth/logout';

  /// GET — Get currently logged-in user profile (requires Bearer token)
  static const String me = '/auth/me';

  /// PUT/PATCH — Update current user profile (name, phone, email, city)
  static const String updateMe = '/auth/me';

  /// POST — Change account password
  static const String changePassword = '/auth/change-password';

  // ═══════════════════════════════════════════════════════════════════════════
  // 📍 ADDRESSES — Customer Saved Addresses (CRUD)
  // ═══════════════════════════════════════════════════════════════════════════
  /// GET / POST — Customer saved addresses
  static const String customerAddresses = '/customer/addresses';

  /// General addresses endpoint alias
  static const String addresses = '/addresses';

  // ═══════════════════════════════════════════════════════════════════════════
  // 🛡️ AUTH — Admin Authentication (Web Portal)
  // ═══════════════════════════════════════════════════════════════════════════
  /// POST — Admin/Staff sign in (strict role check)
  static const String adminLogin = '/auth/admin/login';

  /// POST — Create new admin/staff account
  static const String adminCreateAdmin = '/auth/admin/create-admin';

  /// POST — Create user (general, used by admin panel)
  static const String createUser = '/auth/create-user';

  // ═══════════════════════════════════════════════════════════════════════════
  // 👥 ADMINS — Administrator Management (CRUD)
  // ═══════════════════════════════════════════════════════════════════════════
  /// GET — List all administrators
  static const String adminsList = '/admins';

  /// GET — Get admin by ID → '/admins/:id'
  static String adminById(String id) => '/admins/$id';

  /// POST — Create a new admin → '/admins'
  static const String createAdmin = '/admins';

  /// PUT — Update admin profile → '/admins/:id'
  static String updateAdmin(String id) => '/admins/$id';

  /// DELETE — Delete admin → '/admins/:id'
  static String deleteAdmin(String id) => '/admins/$id';

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔧 SERVICES — Water Service Catalog
  // ═══════════════════════════════════════════════════════════════════════════
  /// GET — List all services (optional ?category= filter)
  static const String services = '/services';

  /// GET — Get service by ID → '/services/:id'
  static String serviceById(String id) => '/services/$id';

  /// POST — Create a new service → '/services'
  static const String createService = '/services';

  /// PUT — Update service → '/services/:id'
  static String updateService(String id) => '/services/$id';

  /// DELETE — Delete service → '/services/:id'
  static String deleteService(String id) => '/services/$id';

  // ═══════════════════════════════════════════════════════════════════════════
  // 📅 BOOKINGS — Service Booking Management
  // ═══════════════════════════════════════════════════════════════════════════
  /// GET — Fetch bookings of authenticated customer (via JWT token) → '/customer/bookings'
  static const String customerBookings = '/customer/bookings';

  /// GET — List all bookings (supports ?status= and ?customerPhone=)
  static const String bookings = '/bookings';

  /// GET — Helper to filter bookings by customer phone
  static String myBookings(String phone) => '/bookings?customerPhone=$phone';

  /// GET — Get booking by ID → '/bookings/:id'
  static String bookingById(String id) => '/bookings/$id';

  /// POST — Create a new booking
  static const String createBooking = '/bookings';

  /// PATCH — Update booking status → '/bookings/:id'
  static String updateBookingStatus(String id) => '/bookings/$id';

  /// POST — Assign technician to booking → '/bookings/:id/assign'
  static String assignBooking(String id) => '/bookings/$id/assign';

  /// POST — Unassign technician from booking → '/bookings/:id/unassign'
  static String unassignBooking(String id) => '/bookings/$id/unassign';

  /// POST — Bulk assign bookings to a technician → '/bookings/bulk-assign'
  static const String bulkAssignBookings = '/bookings/bulk-assign';

  /// GET — Get all bookings assigned to a technician → '/bookings/technician/:techId'
  static String technicianBookings(String techId) => '/bookings/technician/$techId';

  /// POST — Cancel booking → '/bookings/:id/cancel'
  static String cancelBooking(String id) => '/bookings/$id/cancel';

  /// POST — Reschedule booking date/slot → '/bookings/:id/reschedule'
  static String rescheduleBooking(String id) => '/bookings/$id/reschedule';

  /// DELETE — Delete booking → '/bookings/:id'
  static String deleteBooking(String id) => '/bookings/$id';

  // ═══════════════════════════════════════════════════════════════════════════
  // 👷 TECHNICIANS — Technician Management
  // ═══════════════════════════════════════════════════════════════════════════
  /// GET — List all technicians
  static const String technicians = '/technicians';

  /// GET — Get technician by ID → '/technicians/:id'
  static String technicianById(String id) => '/technicians/$id';

  /// PUT — Update technician → '/technicians/:id'
  static String updateTechnician(String id) => '/technicians/$id';

  /// PATCH — Update technician status → '/technicians/:id/status'
  static String updateTechnicianStatus(String id) => '/technicians/$id/status';

  /// DELETE — Delete technician → '/technicians/:id'
  static String deleteTechnician(String id) => '/technicians/$id';

  // ═══════════════════════════════════════════════════════════════════════════
  // 📦 INVENTORY — RO Device & Parts Inventory
  // ═══════════════════════════════════════════════════════════════════════════
  /// GET — List all inventory items
  static const String inventory = '/inventory';

  /// GET — Get inventory stats/metrics
  static const String inventoryStats = '/inventory/stats';

  /// GET — Get inventory item by ID → '/inventory/:id'
  static String inventoryById(String id) => '/inventory/$id';

  /// POST — Create a new inventory item
  static const String createInventoryItem = '/inventory';

  /// POST — Bulk create inventory items
  static const String bulkCreateInventory = '/inventory/bulk';

  /// PUT — Update inventory item → '/inventory/:id'
  static String updateInventoryItem(String id) => '/inventory/$id';

  /// PATCH — Adjust stock quantity → '/inventory/:id/adjust'
  static String adjustStock(String id) => '/inventory/$id/adjust';

  /// POST — Assign device to admin → '/inventory/:id/assign'
  static String assignDevice(String id) => '/inventory/$id/assign';

  /// POST — Unassign device → '/inventory/:id/unassign'
  static String unassignDevice(String id) => '/inventory/$id/unassign';

  /// DELETE — Delete inventory item → '/inventory/:id'
  static String deleteInventoryItem(String id) => '/inventory/$id';

  // ═══════════════════════════════════════════════════════════════════════════
  // 🏷️ CATEGORIES — Device Categories
  // ═══════════════════════════════════════════════════════════════════════════
  /// GET — List all categories
  static const String categories = '/categories';

  /// Also available at: /inventory/categories
  static const String inventoryCategories = '/inventory/categories';

  /// POST — Create category
  static const String createCategory = '/categories';

  /// PUT — Update category → '/categories/:id'
  static String updateCategory(String id) => '/categories/$id';

  /// DELETE — Delete category → '/categories/:id'
  static String deleteCategory(String id) => '/categories/$id';

  // ═══════════════════════════════════════════════════════════════════════════
  // 📊 STATS — Dashboard Statistics
  // ═══════════════════════════════════════════════════════════════════════════
  /// GET — Get dashboard statistics (counts, revenue, etc.)
  static const String dashboardStats = '/stats/dashboard';

  // ═══════════════════════════════════════════════════════════════════════════
  // 💚 HEALTH — Server Health Check
  // ═══════════════════════════════════════════════════════════════════════════
  /// GET — Server health status, uptime, DB connection
  static const String health = '/health';

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎧 SUPPORT — Customer Support Tickets
  // ═══════════════════════════════════════════════════════════════════════════
  /// GET / POST — Support tickets list & create ticket
  static const String supportTickets = '/support/tickets';

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔬 WATER REPORTS — Purifier Diagnostics & Water Reports
  // ═══════════════════════════════════════════════════════════════════════════
  /// GET — My purifier diagnostics and water quality test reports
  static const String myWaterReports = '/water-reports/my';

  /// GET — Single water report by ID → '/water-reports/:id'
  static String waterReportById(String id) => '/water-reports/$id';

  // ═══════════════════════════════════════════════════════════════════════════
  // 📡 TELEMETRY — Real-time IoT Sensor Readings from Purifiers
  // ═══════════════════════════════════════════════════════════════════════════
  /// GET — Get latest telemetry of all active devices
  static const String telemetryLatest = '/telemetry/latest';

  /// GET — Get latest telemetry for a specific device → '/telemetry/:devId/latest'
  static String deviceTelemetryLatest(String devId) => '/telemetry/$devId/latest';

  /// GET — Get historical telemetry logs for a device → '/telemetry/:devId'
  static String deviceTelemetryHistory(String devId) => '/telemetry/$devId';
}

