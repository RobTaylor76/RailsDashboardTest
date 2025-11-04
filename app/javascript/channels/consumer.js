// Action Cable provides the framework to deal with WebSockets in Rails.
// You can generate new channels where WebSocket features live using the `bin/rails generate channel` command.

import { createConsumer } from "@rails/actioncable"

// Get the WebSocket URL from meta tag or default to /cable
const getWebSocketURL = () => {
  const metaTag = document.querySelector('meta[name="action-cable-url"]')
  if (metaTag) {
    return metaTag.getAttribute('content')
  }
  
  // Fallback: construct URL from current location
  const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:'
  const host = window.location.host
  return `${protocol}//${host}/cable`
}

export default createConsumer(getWebSocketURL())
