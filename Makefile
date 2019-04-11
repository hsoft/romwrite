PROGNAME = romwrite
USBDEV = /dev/ttyACM0
BAUDS = 115200
AVRDUDEARGS = -F -V -c arduino -P $(USBDEV) -b $(BAUDS)
AVRDUDEMCU = atmega328p
TARGET = $(PROGNAME).hex

# Rules

.PHONY: send all clean

all: $(TARGET)
	@echo Done!

send: $(PROGNAME).hex
	avrdude $(AVRDUDEARGS) -p $(AVRDUDEMCU) -U flash:w:$<

$(TARGET): main.S
	avra -o $@ $<

clean:
	rm -f $(TARGET) *.S.eep.hex *.S.obj
