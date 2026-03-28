.DEFAULT_GOAL := build

.PHONY: build serve

build:
	hugo

serve:
	hugo serve
