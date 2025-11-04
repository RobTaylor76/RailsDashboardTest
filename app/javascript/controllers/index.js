// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"

// Import controllers as default exports
import HelloController from "controllers/hello_controller"
import DashboardController from "controllers/dashboard_controller"
import SseDashboardController from "controllers/sse_dashboard_controller"
import WebSocketDashboardController from "controllers/websocket_dashboard_controller"

// Manually register controllers with Stimulus
// Controller names are derived from filename: websocket_dashboard_controller.js -> "websocket-dashboard"
application.register("hello", HelloController)
application.register("dashboard", DashboardController)
application.register("sse-dashboard", SseDashboardController)
application.register("websocket-dashboard", WebSocketDashboardController)
