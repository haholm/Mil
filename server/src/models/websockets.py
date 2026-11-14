import asyncio

from fastapi import WebSocket

class DashboardConnections:
    """WebSocket clients subscribed to dashboard refreshes."""

    def __init__(self) -> None:
        self.clients: set[WebSocket] = set()
        self.lock = asyncio.Lock()

    async def connect(self, websocket: WebSocket) -> None:
        await websocket.accept()
        async with self.lock:
            self.clients.add(websocket)

    async def disconnect(self, websocket: WebSocket) -> None:
        async with self.lock:
            self.clients.discard(websocket)

    async def broadcast(self, html: str) -> None:
        async with self.lock:
            clients = tuple(self.clients)
        if not clients:
            return
        results = await asyncio.gather(
            *(client.send_text(html) for client in clients), return_exceptions=True
        )
        disconnected = [
            client for client, result in zip(clients, results)
            if isinstance(result, Exception)
        ]
        if disconnected:
            async with self.lock:
                self.clients.difference_update(disconnected)