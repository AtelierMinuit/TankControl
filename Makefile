# ==============================================================================
# Makefile — HP Smart Tank 500 macOS Native Driver & TankControl Utility
# ==============================================================================

SHELL := /bin/bash

.PHONY: all build test pkg dmg release clean help

all: build test

help:
	@echo "HP Smart Tank 500 — Comandos de compilación disponibles:"
	@echo "  make build    Compila binarios C y TankControl.app"
	@echo "  make test     Ejecuta la suite de pruebas unitarias (228 tests)"
	@echo "  make pkg      Genera el paquete instalador multilingüe .pkg"
	@echo "  make dmg      Genera la imagen de disco distribuible .dmg"
	@echo "  make release  Pipeline completo: build, test, pkg y dmg"
	@echo "  make clean    Elimina directorios temporales de staging"

build:
	@./build_all.sh --binaries --app

test:
	@python3 -m unittest discover -s tests

pkg:
	@./package_dist.sh

dmg:
	@./package_dmg.sh

release:
	@./build_all.sh --all

clean:
	@./build_all.sh --clean
