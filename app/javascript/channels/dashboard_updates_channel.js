import consumer from "channels/consumer"

// NOTE: This subscription is commented out to avoid duplicate subscriptions
// The websocket_dashboard_controller.js handles the subscription instead
// Uncomment if you want this channel to auto-subscribe when loaded

// consumer.subscriptions.create("DashboardUpdatesChannel", {
//   connected() {
//     console.log("📡 DashboardUpdatesChannel auto-subscription connected")
//   },
//
//   disconnected() {
//     console.log("📡 DashboardUpdatesChannel auto-subscription disconnected")
//   },
//
//   received(data) {
//     console.log("📡 DashboardUpdatesChannel auto-subscription received:", data)
//   }
// });
