import { useState, useEffect } from "react";
import { invoke } from "@tauri-apps/api/core";
import { getVersion } from "@tauri-apps/api/app";
import { motion, AnimatePresence } from "framer-motion";
import {
  Network,
  Laptop,
  Power,
  PowerOff,
  LogOut,
  ChevronDown,
  Check,
  Loader2,
  Globe,
  Shield,
  Wifi,
  WifiOff,
  RefreshCw,
} from "lucide-react";
import PleiadesLogo from "./PleiadesLogo";

interface User {
  id: string;
  email: string;
  plan: string;
}

interface NetworkData {
  id: string;
  name: string;
  description: string;
  ip_range: string;
}

interface Device {
  id: string;
  name: string;
  ip_address: string;
  public_key: string;
  is_online: boolean;
  is_exit_node: boolean;
  platform: string;
}

interface DashboardProps {
  user: User;
  onLogout: () => void;
}

type ConnectionStatus = "disconnected" | "connecting" | "connected" | "disconnecting";

export default function Dashboard({ user, onLogout }: DashboardProps) {
  const [networks, setNetworks] = useState<NetworkData[]>([]);
  const [selectedNetwork, setSelectedNetwork] = useState<NetworkData | null>(null);
  const [devices, setDevices] = useState<Device[]>([]);
  const [selectedDevice, setSelectedDevice] = useState<Device | null>(null);
  const [connectionStatus, setConnectionStatus] = useState<ConnectionStatus>("disconnected");
  const [showNetworkSelect, setShowNetworkSelect] = useState(false);
  const [showDeviceSelect, setShowDeviceSelect] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [appVersion, setAppVersion] = useState("");

  useEffect(() => {
    loadNetworks();
    getVersion().then(setAppVersion).catch(() => {});
  }, []);

  useEffect(() => {
    if (selectedNetwork) {
      loadDevices(selectedNetwork.id);
    }
  }, [selectedNetwork]);

  const loadNetworks = async () => {
    try {
      setLoading(true);
      const data = await invoke<NetworkData[]>("get_networks");
      setNetworks(data);
      if (data.length > 0) {
        setSelectedNetwork(data[0]);
      }
    } catch (err: any) {
      setError(err.toString());
    } finally {
      setLoading(false);
    }
  };

  const loadDevices = async (networkId: string) => {
    try {
      const data = await invoke<Device[]>("get_devices", { networkId });
      setDevices(data);
      if (data.length > 0 && !selectedDevice) {
        setSelectedDevice(data[0]);
      }
    } catch (err: any) {
      setError(err.toString());
    }
  };

  const handleConnect = async () => {
    if (!selectedDevice || !selectedNetwork) return;

    setConnectionStatus("connecting");
    try {
      await invoke("connect_vpn", {
        deviceId: selectedDevice.id,
        networkId: selectedNetwork.id
      });
      setConnectionStatus("connected");
    } catch (err: any) {
      setError(err.toString());
      setConnectionStatus("disconnected");
    }
  };

  const handleDisconnect = async () => {
    setConnectionStatus("disconnecting");
    try {
      await invoke("disconnect_vpn");
      setConnectionStatus("disconnected");
    } catch (err: any) {
      setError(err.toString());
      setConnectionStatus("connected");
    }
  };

  const isConnected = connectionStatus === "connected";
  const isConnecting = connectionStatus === "connecting" || connectionStatus === "disconnecting";

  return (
    <div className="min-h-screen p-4">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-2">
          <PleiadesLogo className="w-6 h-6 text-primary" />
          <div className="flex items-center gap-0.5 text-lg font-bold">
            <span className="text-primary">P</span>
            <span>LE</span>
            <span className="text-primary">7</span>
          </div>
        </div>
        <button
          onClick={onLogout}
          className="p-2 rounded-lg text-muted-foreground hover:text-foreground hover:bg-muted transition-colors"
          title="Sign out"
        >
          <LogOut className="w-5 h-5" />
        </button>
      </div>

      {/* Connection Status Card */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className={`rounded-2xl border p-6 mb-4 ${
          isConnected
            ? "bg-green-500/10 border-green-500/30"
            : "bg-card"
        }`}
      >
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-3">
            {isConnected ? (
              <div className="w-12 h-12 rounded-full bg-green-500/20 flex items-center justify-center">
                <Wifi className="w-6 h-6 text-green-500" />
              </div>
            ) : (
              <div className="w-12 h-12 rounded-full bg-muted flex items-center justify-center">
                <WifiOff className="w-6 h-6 text-muted-foreground" />
              </div>
            )}
            <div>
              <p className="font-semibold text-lg">
                {isConnected
                  ? "Connected"
                  : connectionStatus === "connecting"
                  ? "Connecting..."
                  : connectionStatus === "disconnecting"
                  ? "Disconnecting..."
                  : "Disconnected"}
              </p>
              {isConnected && selectedDevice && (
                <p className="text-sm text-muted-foreground">
                  {selectedDevice.ip_address}
                </p>
              )}
            </div>
          </div>

          <button
            onClick={isConnected ? handleDisconnect : handleConnect}
            disabled={isConnecting || !selectedDevice}
            className={`w-16 h-16 rounded-full flex items-center justify-center transition-all ${
              isConnected
                ? "bg-green-500 hover:bg-green-600"
                : "bg-primary hover:opacity-90"
            } disabled:opacity-50`}
          >
            {isConnecting ? (
              <Loader2 className="w-8 h-8 text-white animate-spin" />
            ) : isConnected ? (
              <PowerOff className="w-8 h-8 text-white" />
            ) : (
              <Power className="w-8 h-8 text-white" />
            )}
          </button>
        </div>

        {isConnected && (
          <div className="grid grid-cols-2 gap-3">
            <div className="p-3 rounded-xl bg-background/50">
              <div className="flex items-center gap-2 text-sm text-muted-foreground mb-1">
                <Shield className="w-4 h-4" />
                <span>Encryption</span>
              </div>
              <p className="font-medium">WireGuard</p>
            </div>
            <div className="p-3 rounded-xl bg-background/50">
              <div className="flex items-center gap-2 text-sm text-muted-foreground mb-1">
                <Globe className="w-4 h-4" />
                <span>Network</span>
              </div>
              <p className="font-medium">{selectedNetwork?.name || "-"}</p>
            </div>
          </div>
        )}
      </motion.div>

      {/* Network Selector */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.1 }}
        className="mb-4"
      >
        <label className="block text-sm font-medium text-muted-foreground mb-2">
          Network
        </label>
        <div className="relative">
          <button
            onClick={() => setShowNetworkSelect(!showNetworkSelect)}
            className="w-full flex items-center justify-between p-3 bg-card border rounded-xl hover:bg-muted/50 transition-colors"
          >
            <div className="flex items-center gap-3">
              <Network className="w-5 h-5 text-primary" />
              <span>{selectedNetwork?.name || "Select network"}</span>
            </div>
            <ChevronDown className={`w-4 h-4 transition-transform ${showNetworkSelect ? "rotate-180" : ""}`} />
          </button>

          <AnimatePresence>
            {showNetworkSelect && (
              <motion.div
                initial={{ opacity: 0, y: -10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -10 }}
                className="absolute top-full left-0 right-0 mt-1 bg-card border rounded-xl shadow-lg overflow-hidden z-10"
              >
                {networks.map((network) => (
                  <button
                    key={network.id}
                    onClick={() => {
                      setSelectedNetwork(network);
                      setSelectedDevice(null);
                      setShowNetworkSelect(false);
                    }}
                    className="w-full flex items-center justify-between p-3 hover:bg-muted/50 transition-colors"
                  >
                    <span>{network.name}</span>
                    {selectedNetwork?.id === network.id && (
                      <Check className="w-4 h-4 text-primary" />
                    )}
                  </button>
                ))}
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      </motion.div>

      {/* Device Selector */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.2 }}
        className="mb-4"
      >
        <label className="block text-sm font-medium text-muted-foreground mb-2">
          Device
        </label>
        <div className="relative">
          <button
            onClick={() => setShowDeviceSelect(!showDeviceSelect)}
            className="w-full flex items-center justify-between p-3 bg-card border rounded-xl hover:bg-muted/50 transition-colors"
          >
            <div className="flex items-center gap-3">
              <Laptop className="w-5 h-5 text-primary" />
              <div className="text-left">
                <span>{selectedDevice?.name || "Select device"}</span>
                {selectedDevice && (
                  <p className="text-xs text-muted-foreground">{selectedDevice.ip_address}</p>
                )}
              </div>
            </div>
            <ChevronDown className={`w-4 h-4 transition-transform ${showDeviceSelect ? "rotate-180" : ""}`} />
          </button>

          <AnimatePresence>
            {showDeviceSelect && (
              <motion.div
                initial={{ opacity: 0, y: -10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -10 }}
                className="absolute top-full left-0 right-0 mt-1 bg-card border rounded-xl shadow-lg overflow-hidden z-10 max-h-48 overflow-y-auto"
              >
                {devices.map((device) => (
                  <button
                    key={device.id}
                    onClick={() => {
                      setSelectedDevice(device);
                      setShowDeviceSelect(false);
                    }}
                    className="w-full flex items-center justify-between p-3 hover:bg-muted/50 transition-colors"
                  >
                    <div className="text-left">
                      <span>{device.name}</span>
                      <p className="text-xs text-muted-foreground">{device.ip_address}</p>
                    </div>
                    {selectedDevice?.id === device.id && (
                      <Check className="w-4 h-4 text-primary" />
                    )}
                  </button>
                ))}
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      </motion.div>

      {/* Refresh Button */}
      <motion.button
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.3 }}
        onClick={loadNetworks}
        disabled={loading}
        className="w-full flex items-center justify-center gap-2 p-3 text-muted-foreground hover:text-foreground hover:bg-muted/50 rounded-xl transition-colors"
      >
        <RefreshCw className={`w-4 h-4 ${loading ? "animate-spin" : ""}`} />
        <span>Refresh</span>
      </motion.button>

      {/* Error Display */}
      {error && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          className="mt-4 p-3 rounded-xl bg-destructive/10 text-destructive text-sm"
        >
          {error}
        </motion.div>
      )}

      {/* User Info & Version */}
      <div className="mt-6 text-center text-sm text-muted-foreground">
        <p>{user.email}</p>
        <p className="text-xs mt-1 capitalize">{user.plan.toLowerCase()} Plan</p>
        {appVersion && (
          <p className="text-xs mt-2 text-muted-foreground/50">v{appVersion}</p>
        )}
      </div>
    </div>
  );
}
