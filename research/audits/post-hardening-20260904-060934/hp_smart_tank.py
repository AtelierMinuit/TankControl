#!/usr/bin/env python3
"""
hp_smart_tank.py
Biblioteca y CLI independiente en Python para gestión de la HP Smart Tank 500 series en macOS.
Utiliza libusb-1.0 vía ctypes directamente; requiere libusb disponible en runtime.
"""

from __future__ import annotations

import argparse
import ctypes
import ctypes.util
from dataclasses import dataclass
import os
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

HP_VID = 0x03F0
HP_PID = 0x2B54

# Carga de libusb-1.0
try:
    _path = (
        "/usr/local/lib/libusb-1.0.0.dylib"
        if os.path.exists("/usr/local/lib/libusb-1.0.0.dylib")
        else ctypes.util.find_library("usb-1.0")
        or ctypes.util.find_library("usb")
        or "libusb-1.0.dylib"
    )
    _lib = ctypes.CDLL(_path)
except OSError:
    _lib = None


class _libusb_endpoint_descriptor(ctypes.Structure):
    _fields_ = [
        ("bLength", ctypes.c_uint8),
        ("bDescriptorType", ctypes.c_uint8),
        ("bEndpointAddress", ctypes.c_uint8),
        ("bmAttributes", ctypes.c_uint8),
        ("wMaxPacketSize", ctypes.c_uint16),
        ("bInterval", ctypes.c_uint8),
        ("bRefresh", ctypes.c_uint8),
        ("bSynchAddress", ctypes.c_uint8),
        ("extra", ctypes.c_char_p),
        ("extra_length", ctypes.c_int),
    ]


class _libusb_interface_descriptor(ctypes.Structure):
    _fields_ = [
        ("bLength", ctypes.c_uint8),
        ("bDescriptorType", ctypes.c_uint8),
        ("bInterfaceNumber", ctypes.c_uint8),
        ("bAlternateSetting", ctypes.c_uint8),
        ("bNumEndpoints", ctypes.c_uint8),
        ("bInterfaceClass", ctypes.c_uint8),
        ("bInterfaceSubClass", ctypes.c_uint8),
        ("bInterfaceProtocol", ctypes.c_uint8),
        ("iInterface", ctypes.c_uint8),
        ("endpoint", ctypes.POINTER(_libusb_endpoint_descriptor)),
        ("extra", ctypes.c_char_p),
        ("extra_length", ctypes.c_int),
    ]


class _libusb_interface(ctypes.Structure):
    _fields_ = [
        ("altsetting", ctypes.POINTER(_libusb_interface_descriptor)),
        ("num_altsetting", ctypes.c_int),
    ]


class _libusb_config_descriptor(ctypes.Structure):
    _fields_ = [
        ("bLength", ctypes.c_uint8),
        ("bDescriptorType", ctypes.c_uint8),
        ("wTotalLength", ctypes.c_uint16),
        ("bNumInterfaces", ctypes.c_uint8),
        ("bConfigurationValue", ctypes.c_uint8),
        ("iConfiguration", ctypes.c_uint8),
        ("bmAttributes", ctypes.c_uint8),
        ("MaxPower", ctypes.c_uint8),
        ("interface", ctypes.POINTER(_libusb_interface)),
        ("extra", ctypes.c_char_p),
        ("extra_length", ctypes.c_int),
    ]


class _libusb_device_descriptor(ctypes.Structure):
    _fields_ = [
        ("bLength", ctypes.c_uint8),
        ("bDescriptorType", ctypes.c_uint8),
        ("bcdUSB", ctypes.c_uint16),
        ("bDeviceClass", ctypes.c_uint8),
        ("bDeviceSubClass", ctypes.c_uint8),
        ("bDeviceProtocol", ctypes.c_uint8),
        ("bMaxPacketSize0", ctypes.c_uint8),
        ("idVendor", ctypes.c_uint16),
        ("idProduct", ctypes.c_uint16),
        ("bcdDevice", ctypes.c_uint16),
        ("iManufacturer", ctypes.c_uint8),
        ("iProduct", ctypes.c_uint8),
        ("iSerialNumber", ctypes.c_uint8),
        ("bNumConfigurations", ctypes.c_uint8),
    ]


if _lib:
    _lib.libusb_init.argtypes = [ctypes.POINTER(ctypes.c_void_p)]
    _lib.libusb_init.restype = ctypes.c_int
    _lib.libusb_exit.argtypes = [ctypes.c_void_p]
    _lib.libusb_exit.restype = None

    _lib.libusb_open_device_with_vid_pid.argtypes = [ctypes.c_void_p, ctypes.c_uint16, ctypes.c_uint16]
    _lib.libusb_open_device_with_vid_pid.restype = ctypes.c_void_p

    _lib.libusb_close.argtypes = [ctypes.c_void_p]
    _lib.libusb_close.restype = None

    _lib.libusb_get_device.argtypes = [ctypes.c_void_p]
    _lib.libusb_get_device.restype = ctypes.c_void_p

    _lib.libusb_get_active_config_descriptor.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.POINTER(_libusb_config_descriptor))]
    _lib.libusb_get_active_config_descriptor.restype = ctypes.c_int

    _lib.libusb_free_config_descriptor.argtypes = [ctypes.POINTER(_libusb_config_descriptor)]
    _lib.libusb_free_config_descriptor.restype = None

    _lib.libusb_claim_interface.argtypes = [ctypes.c_void_p, ctypes.c_int]
    _lib.libusb_claim_interface.restype = ctypes.c_int

    _lib.libusb_set_auto_detach_kernel_driver.argtypes = [ctypes.c_void_p, ctypes.c_int]
    _lib.libusb_set_auto_detach_kernel_driver.restype = ctypes.c_int

    _lib.libusb_release_interface.argtypes = [ctypes.c_void_p, ctypes.c_int]
    _lib.libusb_release_interface.restype = ctypes.c_int

    _lib.libusb_bulk_transfer.argtypes = [
        ctypes.c_void_p, ctypes.c_uint8, ctypes.c_char_p, ctypes.c_int,
        ctypes.POINTER(ctypes.c_int), ctypes.c_uint
    ]
    _lib.libusb_bulk_transfer.restype = ctypes.c_int


@dataclass
class ChannelInfo:
    interface_number: int
    ep_in: int
    ep_out: int
    ep_in_max_size: int
    ep_out_max_size: int


class SmartTank500:
    MAX_HTTP_RESPONSE = 1024 * 1024

    def __init__(self) -> None:
        if not _lib:
            raise RuntimeError("libusb-1.0 no disponible en el sistema.")
        self.ctx = ctypes.c_void_p()
        ret = _lib.libusb_init(ctypes.byref(self.ctx))
        if ret != 0:
            raise RuntimeError(f"Fallo al inicializar libusb (error {ret})")
        self.handle = None

    def __enter__(self) -> SmartTank500:
        return self

    def __exit__(self, exc_type, exc_val, exc_tb) -> None:
        self.close()

    def close(self) -> None:
        if self.handle:
            _lib.libusb_close(self.handle)
            self.handle = None
        if self.ctx:
            _lib.libusb_exit(self.ctx)
            self.ctx = None

    def is_connected(self) -> bool:
        test_h = _lib.libusb_open_device_with_vid_pid(self.ctx, HP_VID, HP_PID)
        if test_h:
            _lib.libusb_close(test_h)
            return True
        return False

    def find_channel(self, target_class: int, target_subclass: int, target_proto: int) -> ChannelInfo | None:
        if not self.handle:
            self.handle = _lib.libusb_open_device_with_vid_pid(self.ctx, HP_VID, HP_PID)
            if not self.handle:
                return None
        dev = _lib.libusb_get_device(self.handle)
        cfg_ptr = ctypes.POINTER(_libusb_config_descriptor)()
        if _lib.libusb_get_active_config_descriptor(dev, ctypes.byref(cfg_ptr)) != 0:
            return None
        try:
            cfg = cfg_ptr.contents
            for i in range(cfg.bNumInterfaces):
                inter = cfg.interface[i]
                for a in range(inter.num_altsetting):
                    d = inter.altsetting[a]
                    if d.bInterfaceClass == target_class and d.bInterfaceSubClass == target_subclass and d.bInterfaceProtocol == target_proto:
                        ep_in, ep_out, ep_in_sz, ep_out_sz = 0, 0, 0, 0
                        for e in range(d.bNumEndpoints):
                            ep = d.endpoint[e]
                            if (ep.bmAttributes & 0x03) != 0x02:
                                continue  # Filtrar endpoints no-BULK (como Interrupt 0x83)
                            if ep.bEndpointAddress & 0x80:
                                ep_in = ep.bEndpointAddress
                                ep_in_sz = ep.wMaxPacketSize
                            else:
                                ep_out = ep.bEndpointAddress
                                ep_out_sz = ep.wMaxPacketSize
                        return ChannelInfo(d.bInterfaceNumber, ep_in, ep_out, ep_in_sz, ep_out_sz)
            return None
        finally:
            _lib.libusb_free_config_descriptor(cfg_ptr)

    def query_http(self, chan: ChannelInfo, path: str) -> str:
        _lib.libusb_set_auto_detach_kernel_driver(self.handle, 1)
        if _lib.libusb_claim_interface(self.handle, chan.interface_number) != 0:
            raise RuntimeError("No se pudo reclamar la interfaz USB")
        try:
            req = f"GET {path} HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n".encode("ascii")
            transferred = ctypes.c_int()
            if _lib.libusb_bulk_transfer(self.handle, chan.ep_out, req, len(req), ctypes.byref(transferred), 5000) != 0:
                raise RuntimeError("No se pudo enviar la consulta HTTP USB")

            buf = ctypes.create_string_buffer(65536)
            total_data = bytearray()
            complete = False
            while True:
                chunk = ctypes.c_int()
                r = _lib.libusb_bulk_transfer(self.handle, chan.ep_in, buf, 65535, ctypes.byref(chunk), 2000)
                if r == 0 and chunk.value > 0:
                    total_data.extend(buf.raw[: chunk.value])
                    if len(total_data) > self.MAX_HTTP_RESPONSE:
                        raise RuntimeError("Respuesta HTTP USB demasiado grande")
                    if b"\r\n\r\n" in total_data:
                        hdr, body = total_data.split(b"\r\n\r\n", 1)
                        if re.search(rb"^Transfer-Encoding:\s*chunked\s*$", hdr, re.I | re.M):
                            raise RuntimeError("Transfer-Encoding chunked no soportado de forma segura")
                        cl_m = re.search(rb"^Content-Length:\s*(\d+)\s*$", hdr, re.I | re.M)
                        if not cl_m:
                            raise RuntimeError("Respuesta HTTP USB sin Content-Length")
                        content_length = int(cl_m.group(1))
                        if content_length > self.MAX_HTTP_RESPONSE:
                            raise RuntimeError("Content-Length HTTP USB demasiado grande")
                        if len(body) >= content_length:
                            complete = True
                            break
                elif r != 0:
                    raise RuntimeError(f"Error leyendo respuesta HTTP USB ({r})")
                else:
                    break
            if not complete:
                raise RuntimeError("Respuesta HTTP USB incompleta")
            return total_data.decode("utf-8", errors="replace")
        finally:
            _lib.libusb_release_interface(self.handle, chan.interface_number)


def main() -> int:
    parser = argparse.ArgumentParser(description="Gestor nativo HP Smart Tank 500 para macOS Apple Silicon")
    parser.add_argument("command", choices=["info", "status", "supplies", "scan-caps", "scan-status"], help="Comando a ejecutar")
    args = parser.parse_args()

    try:
        with SmartTank500() as st:
            if not st.is_connected():
                print("Aviso: HP Smart Tank 500 (03f0:2b54) no detectada en bus USB.")
                print("Conecte el cable USB y encienda el equipo para operar.")
                return 1

            if args.command == "info":
                print("HP Smart Tank 500 detectada correctamente en el bus USB.")
            elif args.command == "supplies":
                chan = st.find_channel(0xFF, 0x04, 0x01)
                if not chan:
                    raise RuntimeError("No se encontró el canal USB de gestión")
                resp = st.query_http(chan, "/DevMgmt/ConsumableConfigDyn.xml")
                print(resp)
            elif args.command == "status":
                chan = st.find_channel(0xFF, 0x04, 0x01)
                if not chan:
                    raise RuntimeError("No se encontró el canal USB de gestión")
                resp = st.query_http(chan, "/DevMgmt/ProductStatusDyn.xml")
                print(resp)
            elif args.command == "scan-caps":
                chan = st.find_channel(0xFF, 0xCC, 0x00)
                if not chan:
                    raise RuntimeError("No se encontró el canal USB del escáner")
                resp = st.query_http(chan, "/Scan/ScanCaps")
                print(resp)
            elif args.command == "scan-status":
                chan = st.find_channel(0xFF, 0xCC, 0x00)
                if not chan:
                    raise RuntimeError("No se encontró el canal USB del escáner")
                resp = st.query_http(chan, "/Scan/Status")
                print(resp)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
