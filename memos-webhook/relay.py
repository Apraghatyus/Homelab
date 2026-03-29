#!/usr/bin/env python3
"""
Memos → ntfy webhook relay
Recibe el JSON crudo del webhook de Memos, lo formatea y reenvía a ntfy.
Puerto: 5231
Servicio: systemd (memos-webhook.service)
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import urllib.request
import base64
import sys

# === CONFIGURACIÓN ===
LISTEN_PORT = 5231
NTFY_URL = "http://100.122.46.43:8090/memos-webhooks"
# Sin autenticación: el topic memos-webhooks tiene acceso de escritura anónimo

# Mapeo de tipos de actividad
ACTIVITY_MAP = {
    "memos.memo.created": {"emoji": "", "action": "Nuevo memo", "priority": "default"},
    "memos.memo.updated": {"emoji": "", "action": "Memo editado", "priority": "low"},
    "memos.memo.deleted": {"emoji": "", "action": "Memo eliminado", "priority": "default"},
    "memos.memo.shared": {"emoji": "", "action": "Memo compartido", "priority": "default"},
    "memos.resource.uploaded": {"emoji": "", "action": "Archivo subido", "priority": "low"},
}

VISIBILITY_MAP = {
    0: "Público",
    1: "Privado",
    2: "Protegido",
}


class WebhookHandler(BaseHTTPRequestHandler):

    def do_POST(self):
        try:
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length)
            payload = json.loads(body)

            activity = payload.get("activityType", "unknown")
            info = ACTIVITY_MAP.get(activity, {"emoji": "", "action": activity, "priority": "default"})

            # Extraer datos del memo
            memo = payload.get("memo", {})
            content = memo.get("content", "")
            creator = payload.get("creator", "unknown")
            visibility = VISIBILITY_MAP.get(memo.get("visibility"), "Desconocido")

            # Truncar contenido a 200 caracteres
            if len(content) > 200:
                content = content[:200] + "..."

            # Adjuntos
            attachments = memo.get("attachments", [])
            attachment_text = ""
            if attachments:
                filenames = [a.get("filename", "?") for a in attachments]
                attachment_text = f"\n Adjuntos: {', '.join(filenames)}"

            # Formatear título y mensaje
            title = f"{info['emoji']} {info['action']}"
            message_parts = []
            if content:
                message_parts.append(content)
            message_parts.append(f" {creator} ·  {visibility}")
            if attachment_text:
                message_parts.append(attachment_text.strip())

            message = "\n".join(message_parts)

            # Enviar a ntfy
            req = urllib.request.Request(
                NTFY_URL,
                data=message.encode("utf-8"),
                method="POST",
            )
            req.add_header("Title", title)
            req.add_header("Tags", "memo")
            req.add_header("Priority", info["priority"])

            urllib.request.urlopen(req, timeout=10)

            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'{"status":"ok"}')

        except Exception as e:
            print(f"Error procesando webhook: {e}", file=sys.stderr)
            self.send_response(500)
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(e)}).encode())

    def log_message(self, format, *args):
        """Silenciar logs de acceso para no llenar journalctl."""
        pass


if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", LISTEN_PORT), WebhookHandler)
    print(f"Memos webhook relay escuchando en 127.0.0.1:{LISTEN_PORT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nRelay detenido.")
        server.server_close()
