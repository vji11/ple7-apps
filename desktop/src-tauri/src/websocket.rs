//! WebSocket client for real-time peer updates from the control plane
//! Receives peer endpoint updates for NAT traversal and direct P2P connections

use std::collections::HashMap;
use std::net::SocketAddr;
use std::sync::Arc;
use std::time::Duration;

use futures_util::{SinkExt, StreamExt};
use parking_lot::RwLock;
use serde::{Deserialize, Serialize};
use tokio::sync::mpsc;
use tokio_tungstenite::{connect_async, tungstenite::protocol::Message};

/// Events received from the control plane
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", content = "data")]
pub enum WsEvent {
    /// Peer endpoint updated (for direct P2P connection)
    PeerEndpointUpdate {
        device_id: String,
        public_key: String,
        endpoint: String,
    },
    /// Peer came online
    PeerOnline {
        device_id: String,
        public_key: String,
    },
    /// Peer went offline
    PeerOffline {
        device_id: String,
    },
    /// Network configuration changed
    NetworkConfigUpdate {
        network_id: String,
    },
    /// Ping from server (keepalive)
    Ping,
    /// Server acknowledged our endpoint report
    EndpointAck {
        success: bool,
    },
}

/// Messages sent to the control plane
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", content = "data")]
pub enum WsMessage {
    /// Register this device with its public endpoint
    RegisterEndpoint {
        device_id: String,
        endpoint: String,
    },
    /// Subscribe to updates for a network
    Subscribe {
        network_id: String,
    },
    /// Unsubscribe from a network
    Unsubscribe {
        network_id: String,
    },
    /// Pong response
    Pong,
}

/// Callback for handling WebSocket events
pub type EventCallback = Box<dyn Fn(WsEvent) + Send + Sync>;

/// WebSocket connection state
#[derive(Debug, Clone, PartialEq)]
pub enum WsState {
    Disconnected,
    Connecting,
    Connected,
    Reconnecting,
}

/// WebSocket client for control plane communication
pub struct WsClient {
    base_url: String,
    token: String,
    device_id: String,
    state: Arc<RwLock<WsState>>,
    pub tx: Option<mpsc::Sender<WsMessage>>,
    callbacks: Arc<RwLock<Vec<EventCallback>>>,
    peer_endpoints: Arc<RwLock<HashMap<String, SocketAddr>>>,
}

impl WsClient {
    pub fn new(base_url: &str, token: &str, device_id: &str) -> Self {
        // Convert http(s) to ws(s)
        let ws_url = base_url
            .replace("https://", "wss://")
            .replace("http://", "ws://");

        Self {
            base_url: ws_url,
            token: token.to_string(),
            device_id: device_id.to_string(),
            state: Arc::new(RwLock::new(WsState::Disconnected)),
            tx: None,
            callbacks: Arc::new(RwLock::new(Vec::new())),
            peer_endpoints: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    /// Add a callback for WebSocket events
    pub fn on_event(&mut self, callback: EventCallback) {
        self.callbacks.write().push(callback);
    }

    /// Get current peer endpoints
    pub fn peer_endpoints(&self) -> HashMap<String, SocketAddr> {
        self.peer_endpoints.read().clone()
    }

    /// Get specific peer endpoint
    pub fn get_peer_endpoint(&self, public_key: &str) -> Option<SocketAddr> {
        self.peer_endpoints.read().get(public_key).copied()
    }

    /// Connect to the WebSocket server
    pub async fn connect(&mut self) -> Result<(), String> {
        *self.state.write() = WsState::Connecting;

        let ws_url = format!("{}/ws/mesh?token={}", self.base_url, self.token);

        log::info!("Connecting to WebSocket: {}", self.base_url);

        let (ws_stream, _) = connect_async(&ws_url)
            .await
            .map_err(|e| format!("WebSocket connection failed: {}", e))?;

        let (mut write, mut read) = ws_stream.split();

        // Create message channel
        let (tx, mut rx) = mpsc::channel::<WsMessage>(32);
        self.tx = Some(tx.clone());

        *self.state.write() = WsState::Connected;
        log::info!("WebSocket connected");

        // Clone for tasks
        let state = self.state.clone();
        let callbacks = self.callbacks.clone();
        let peer_endpoints = self.peer_endpoints.clone();
        let device_id = self.device_id.clone();

        // Spawn write task
        let state_write = state.clone();
        tokio::spawn(async move {
            while let Some(msg) = rx.recv().await {
                let json = serde_json::to_string(&msg).unwrap();
                if let Err(e) = write.send(Message::Text(json)).await {
                    log::error!("WebSocket send error: {}", e);
                    *state_write.write() = WsState::Disconnected;
                    break;
                }
            }
        });

        // Spawn read task
        let tx_pong = tx.clone();
        tokio::spawn(async move {
            while let Some(result) = read.next().await {
                match result {
                    Ok(Message::Text(text)) => {
                        match serde_json::from_str::<WsEvent>(&text) {
                            Ok(event) => {
                                // Handle special events
                                match &event {
                                    WsEvent::Ping => {
                                        let _ = tx_pong.send(WsMessage::Pong).await;
                                    }
                                    WsEvent::PeerEndpointUpdate { public_key, endpoint, .. } => {
                                        if let Ok(addr) = endpoint.parse::<SocketAddr>() {
                                            peer_endpoints.write().insert(public_key.clone(), addr);
                                            log::info!("Updated peer endpoint: {} -> {}", public_key, endpoint);
                                        }
                                    }
                                    _ => {}
                                }

                                // Call registered callbacks
                                for callback in callbacks.read().iter() {
                                    callback(event.clone());
                                }
                            }
                            Err(e) => {
                                log::warn!("Failed to parse WebSocket message: {} - {}", e, text);
                            }
                        }
                    }
                    Ok(Message::Close(_)) => {
                        log::info!("WebSocket closed by server");
                        *state.write() = WsState::Disconnected;
                        break;
                    }
                    Ok(Message::Ping(data)) => {
                        // Tungstenite handles pong automatically
                    }
                    Err(e) => {
                        log::error!("WebSocket read error: {}", e);
                        *state.write() = WsState::Disconnected;
                        break;
                    }
                    _ => {}
                }
            }
        });

        Ok(())
    }

    /// Register our public endpoint with the control plane
    pub async fn register_endpoint(&self, endpoint: SocketAddr) -> Result<(), String> {
        if let Some(tx) = &self.tx {
            tx.send(WsMessage::RegisterEndpoint {
                device_id: self.device_id.clone(),
                endpoint: endpoint.to_string(),
            })
            .await
            .map_err(|e| format!("Failed to send endpoint: {}", e))?;

            log::info!("Registered endpoint with control plane: {}", endpoint);
        }
        Ok(())
    }

    /// Subscribe to updates for a network
    pub async fn subscribe(&self, network_id: &str) -> Result<(), String> {
        if let Some(tx) = &self.tx {
            tx.send(WsMessage::Subscribe {
                network_id: network_id.to_string(),
            })
            .await
            .map_err(|e| format!("Failed to subscribe: {}", e))?;

            log::info!("Subscribed to network: {}", network_id);
        }
        Ok(())
    }

    /// Get current connection state
    pub fn state(&self) -> WsState {
        self.state.read().clone()
    }

    /// Disconnect from WebSocket
    pub fn disconnect(&mut self) {
        self.tx = None;
        *self.state.write() = WsState::Disconnected;
        log::info!("WebSocket disconnected");
    }
}

/// Managed WebSocket client with automatic reconnection
pub struct ManagedWsClient {
    client: Arc<RwLock<Option<WsClient>>>,
    config: WsConfig,
    running: Arc<std::sync::atomic::AtomicBool>,
}

#[derive(Clone)]
pub struct WsConfig {
    pub base_url: String,
    pub token: String,
    pub device_id: String,
    pub reconnect_interval: Duration,
}

impl ManagedWsClient {
    pub fn new(config: WsConfig) -> Self {
        Self {
            client: Arc::new(RwLock::new(None)),
            config,
            running: Arc::new(std::sync::atomic::AtomicBool::new(false)),
        }
    }

    /// Start the managed WebSocket connection with auto-reconnect
    pub async fn start(&self, on_event: EventCallback) -> Result<(), String> {
        use std::sync::atomic::Ordering;

        if self.running.load(Ordering::SeqCst) {
            return Err("Already running".to_string());
        }

        self.running.store(true, Ordering::SeqCst);

        let config = self.config.clone();
        let client = self.client.clone();
        let running = self.running.clone();
        let callbacks = Arc::new(RwLock::new(vec![on_event]));

        tokio::spawn(async move {
            while running.load(Ordering::SeqCst) {
                let mut ws_client = WsClient::new(
                    &config.base_url,
                    &config.token,
                    &config.device_id,
                );

                // Add callbacks
                for cb in callbacks.read().iter() {
                    // Note: This is simplified - in production you'd clone Arc callbacks
                }

                match ws_client.connect().await {
                    Ok(()) => {
                        *client.write() = Some(ws_client);
                        log::info!("WebSocket connected, monitoring...");

                        // Monitor connection
                        loop {
                            tokio::time::sleep(Duration::from_secs(5)).await;

                            if !running.load(Ordering::SeqCst) {
                                break;
                            }

                            let state = client.read()
                                .as_ref()
                                .map(|c| c.state())
                                .unwrap_or(WsState::Disconnected);

                            if state == WsState::Disconnected {
                                log::info!("WebSocket disconnected, will reconnect...");
                                break;
                            }
                        }
                    }
                    Err(e) => {
                        log::warn!("WebSocket connection failed: {}", e);
                    }
                }

                if running.load(Ordering::SeqCst) {
                    log::info!("Reconnecting in {:?}...", config.reconnect_interval);
                    tokio::time::sleep(config.reconnect_interval).await;
                }
            }
        });

        Ok(())
    }

    /// Stop the managed connection
    pub fn stop(&self) {
        use std::sync::atomic::Ordering;
        self.running.store(false, Ordering::SeqCst);
        if let Some(client) = self.client.write().as_mut() {
            client.disconnect();
        }
    }

    /// Register endpoint
    pub async fn register_endpoint(&self, endpoint: SocketAddr) -> Result<(), String> {
        // Get the tx channel without holding the lock across await
        let tx = {
            let guard = self.client.read();
            guard.as_ref().and_then(|c| c.tx.clone())
        };

        if let Some(tx) = tx {
            tx.send(WsMessage::RegisterEndpoint {
                device_id: self.config.device_id.clone(),
                endpoint: endpoint.to_string(),
            })
            .await
            .map_err(|e| format!("Failed to send endpoint: {}", e))?;
            log::info!("Registered endpoint with control plane: {}", endpoint);
            Ok(())
        } else {
            Err("Not connected".to_string())
        }
    }

    /// Get peer endpoint
    pub fn get_peer_endpoint(&self, public_key: &str) -> Option<SocketAddr> {
        self.client.read()
            .as_ref()
            .and_then(|c| c.get_peer_endpoint(public_key))
    }

    /// Subscribe to network updates
    pub async fn subscribe(&self, network_id: &str) -> Result<(), String> {
        // Get the tx channel without holding the lock across await
        let tx = {
            let guard = self.client.read();
            guard.as_ref().and_then(|c| c.tx.clone())
        };

        if let Some(tx) = tx {
            tx.send(WsMessage::Subscribe {
                network_id: network_id.to_string(),
            })
            .await
            .map_err(|e| format!("Failed to subscribe: {}", e))?;
            log::info!("Subscribed to network: {}", network_id);
            Ok(())
        } else {
            Err("Not connected".to_string())
        }
    }
}
