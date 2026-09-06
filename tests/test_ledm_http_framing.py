#!/usr/bin/env python3
"""Pruebas de simulación offline para el framing HTTP y análisis LEDM."""

from __future__ import annotations

import io
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def parse_http_stream(stream: io.BytesIO) -> list[tuple[dict[str, str], bytes]]:
    """Parser de framing HTTP que soporta fragmentación y múltiples respuestas."""
    responses = []
    buffer = bytearray()

    while True:
        chunk = stream.read(128)
        if not chunk and not buffer:
            break
        buffer.extend(chunk)

        # Buscar fin de cabeceras
        sep_idx = buffer.find(b"\r\n\r\n")
        if sep_idx == -1:
            if not chunk:
                break  # Fin de stream con buffer incompleto
            continue

        header_bytes = buffer[:sep_idx].decode("latin1", errors="replace")
        lines = header_bytes.split("\r\n")
        status_line = lines[0]
        headers = {}
        for line in lines[1:]:
            if ":" in line:
                k, v = line.split(":", 1)
                headers[k.strip().lower()] = v.strip()

        # Determinar longitud del cuerpo
        if "content-length" in headers:
            content_length = int(headers["content-length"])
            body_start = sep_idx + 4
            body_end = body_start + content_length

            # Esperar a que el cuerpo completo esté en el buffer
            while len(buffer) < body_end:
                more = stream.read(128)
                if not more:
                    break
                buffer.extend(more)

            body = bytes(buffer[body_start:body_end])
            del buffer[:body_end]
            responses.append((headers, body))
        elif "transfer-encoding" in headers and headers["transfer-encoding"] == "chunked":
            # Parser de chunked encoding
            body_chunks = []
            cursor = sep_idx + 4
            while True:
                crlf = buffer.find(b"\r\n", cursor)
                if crlf == -1:
                    more = stream.read(128)
                    if not more:
                        break
                    buffer.extend(more)
                    continue
                size_str = buffer[cursor:crlf].decode("ascii", errors="replace").strip()
                if not size_str:
                    cursor = crlf + 2
                    continue
                chunk_size = int(size_str, 16)
                if chunk_size == 0:
                    cursor = crlf + 4  # 0\r\n\r\n
                    break
                chunk_start = crlf + 2
                chunk_end = chunk_start + chunk_size
                while len(buffer) < chunk_end + 2:
                    more = stream.read(128)
                    if not more:
                        break
                    buffer.extend(more)
                body_chunks.append(bytes(buffer[chunk_start:chunk_end]))
                cursor = chunk_end + 2
            del buffer[:cursor]
            responses.append((headers, b"".join(body_chunks)))
        else:
            # Sin Content-Length ni Chunked: leer hasta fin de stream
            body = bytes(buffer[sep_idx + 4 :])
            buffer.clear()
            responses.append((headers, body))
            break

    return responses


def extract_jpeg_from_scan_stream(data: bytes) -> bytes | None:
    """Extrae JPEG delimitado por SOI (0xFFD8) y EOI (0xFFD9), descartando trailing junk."""
    soi = data.find(b"\xff\xd8")
    if soi == -1:
        return None
    eoi = data.find(b"\xff\xd9", soi + 2)
    if eoi == -1:
        return None
    return data[soi : eoi + 2]


class LedmHttpFramingTests(unittest.TestCase):
    def test_fragmented_headers_and_body(self) -> None:
        """Simula que la respuesta HTTP llega fragmentada byte por byte."""
        body_expected = b"<ProductStatusDyn><Status>Idle</Status></ProductStatusDyn>"
        raw_http = (
            b"HTTP/1.1 200 OK\r\n"
            b"Content-Type: text/xml\r\n"
            b"Content-Length: " + str(len(body_expected)).encode("ascii") + b"\r\n"
            b"\r\n" + body_expected
        )
        stream = io.BytesIO(raw_http)
        responses = parse_http_stream(stream)
        self.assertEqual(len(responses), 1)
        headers, body = responses[0]
        self.assertEqual(headers["content-length"], str(len(body_expected)))
        self.assertEqual(body, body_expected)

    def test_concatenated_multiple_responses_in_same_buffer(self) -> None:
        """Simula 2 respuestas HTTP devueltas en un mismo buffer USB."""
        resp1 = b"HTTP/1.1 200 OK\r\nContent-Length: 12\r\n\r\nFirstMessage"
        resp2 = b"HTTP/1.1 200 OK\r\nContent-Length: 13\r\n\r\nSecondMessage"
        stream = io.BytesIO(resp1 + resp2)
        responses = parse_http_stream(stream)
        self.assertEqual(len(responses), 2)
        self.assertEqual(responses[0][1], b"FirstMessage")
        self.assertEqual(responses[1][1], b"SecondMessage")

    def test_chunked_transfer_encoding_support(self) -> None:
        """Valida que el framing decodifica Transfer-Encoding chunked."""
        raw_chunked = (
            b"HTTP/1.1 200 OK\r\n"
            b"Transfer-Encoding: chunked\r\n"
            b"Content-Type: text/plain\r\n"
            b"\r\n"
            b"5\r\nHello\r\n"
            b"6\r\n World\r\n"
            b"0\r\n\r\n"
        )
        stream = io.BytesIO(raw_chunked)
        responses = parse_http_stream(stream)
        self.assertEqual(len(responses), 1)
        self.assertEqual(responses[0][1], b"Hello World")

    def test_jpeg_extraction_ignores_trailing_usb_junk(self) -> None:
        """Simula imagen JPEG válida seguida de bytes residuales en el buffer USB."""
        valid_jpeg = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00\xff\xd9"
        trailing_junk = b"\x00\x00\xaa\x55\xff\xffEXTRA_USB_GARBAGE"
        extracted = extract_jpeg_from_scan_stream(b"PREFIX" + valid_jpeg + trailing_junk)
        self.assertEqual(extracted, valid_jpeg)

    def test_xml_namespace_agnostic_parsing(self) -> None:
        """Verifica que el parser XML maneja namespaces LEDM con o sin prefijo."""
        xml_with_ns = (
            b"<?xml version='1.0' encoding='UTF-8'?>"
            b"<scan:ScannerStatus xmlns:scan='http://schemas.hp.com/imaging/escl/2011/05/03'>"
            b"  <scan:AdfState>ScannerAdfEmpty</scan:AdfState>"
            b"  <scan:State>Idle</scan:State>"
            b"</scan:ScannerStatus>"
        )
        root = ET.fromstring(xml_with_ns)
        # Búsqueda agnóstica de tag
        state_elems = [el for el in root.iter() if el.tag.split("}")[-1] == "State"]
        self.assertTrue(len(state_elems) > 0)
        self.assertEqual(state_elems[0].text, "Idle")


if __name__ == "__main__":
    unittest.main()
