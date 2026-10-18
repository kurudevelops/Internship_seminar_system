from typing import List
from fastapi import WebSocket


class RealtimeConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def broadcast_update(self, event_type: str = "ROSTER_UPDATED"):
        disconnected: List[WebSocket] = []
        for connection in self.active_connections:
            try:
                await connection.send_json({"event": event_type})
            except Exception:
                disconnected.append(connection)

        for dead_conn in disconnected:
            self.disconnect(dead_conn)


realtime_manager = RealtimeConnectionManager()