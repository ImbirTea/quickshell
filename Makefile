LAUNCHER_DIR := modules/launcher/list-applications

.PHONY: build clean

build:
	cd $(LAUNCHER_DIR) && cargo build --release

clean:
	cd $(LAUNCHER_DIR) && cargo clean