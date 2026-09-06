#include <libusb.h>

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

enum {
    HP_VENDOR_ID = 0x03f0,
    SMART_TANK_500_PRODUCT_ID = 0x2b54,
};

static const char *transfer_type(uint8_t attributes)
{
    switch (attributes & LIBUSB_TRANSFER_TYPE_MASK) {
    case LIBUSB_TRANSFER_TYPE_CONTROL:
        return "control";
    case LIBUSB_TRANSFER_TYPE_ISOCHRONOUS:
        return "isochronous";
    case LIBUSB_TRANSFER_TYPE_BULK:
        return "bulk";
    case LIBUSB_TRANSFER_TYPE_INTERRUPT:
        return "interrupt";
    default:
        return "unknown";
    }
}

static const char *direction(uint8_t address)
{
    return (address & LIBUSB_ENDPOINT_IN) ? "IN" : "OUT";
}

static int print_device(libusb_device *device,
                        const struct libusb_device_descriptor *descriptor)
{
    printf("device vid=0x%04x pid=0x%04x bus=%u address=%u\n",
           descriptor->idVendor,
           descriptor->idProduct,
           libusb_get_bus_number(device),
           libusb_get_device_address(device));
    printf("  bcdUSB=0x%04x bcdDevice=0x%04x class=0x%02x "
           "subclass=0x%02x protocol=0x%02x max_packet_0=%u configurations=%u\n",
           descriptor->bcdUSB,
           descriptor->bcdDevice,
           descriptor->bDeviceClass,
           descriptor->bDeviceSubClass,
           descriptor->bDeviceProtocol,
           descriptor->bMaxPacketSize0,
           descriptor->bNumConfigurations);
    printf("  string_indices manufacturer=%u product=%u serial=%u\n",
           descriptor->iManufacturer,
           descriptor->iProduct,
           descriptor->iSerialNumber);

    for (uint8_t config_index = 0;
         config_index < descriptor->bNumConfigurations;
         ++config_index) {
        struct libusb_config_descriptor *config = NULL;
        int rc = libusb_get_config_descriptor(device, config_index, &config);
        if (rc != LIBUSB_SUCCESS) {
            fprintf(stderr,
                    "configuration %u unavailable: %s\n",
                    config_index,
                    libusb_error_name(rc));
            return 1;
        }

        printf("  configuration index=%u value=%u interfaces=%u "
               "attributes=0x%02x max_power_ma=%u total_length=%u string_index=%u\n",
               config_index,
               config->bConfigurationValue,
               config->bNumInterfaces,
               config->bmAttributes,
               config->MaxPower * 2,
               config->wTotalLength,
               config->iConfiguration);

        for (uint8_t interface_index = 0;
             interface_index < config->bNumInterfaces;
             ++interface_index) {
            const struct libusb_interface *interface =
                &config->interface[interface_index];
            for (int alt_index = 0;
                 alt_index < interface->num_altsetting;
                 ++alt_index) {
                const struct libusb_interface_descriptor *alt =
                    &interface->altsetting[alt_index];
                printf("    interface=%u alt=%u class=0x%02x subclass=0x%02x "
                       "protocol=0x%02x endpoints=%u string_index=%u\n",
                       alt->bInterfaceNumber,
                       alt->bAlternateSetting,
                       alt->bInterfaceClass,
                       alt->bInterfaceSubClass,
                       alt->bInterfaceProtocol,
                       alt->bNumEndpoints,
                       alt->iInterface);

                for (uint8_t endpoint_index = 0;
                     endpoint_index < alt->bNumEndpoints;
                     ++endpoint_index) {
                    const struct libusb_endpoint_descriptor *endpoint =
                        &alt->endpoint[endpoint_index];
                    printf("      endpoint=0x%02x direction=%s type=%s "
                           "max_packet=%u interval=%u attributes=0x%02x\n",
                           endpoint->bEndpointAddress,
                           direction(endpoint->bEndpointAddress),
                           transfer_type(endpoint->bmAttributes),
                           endpoint->wMaxPacketSize,
                           endpoint->bInterval,
                           endpoint->bmAttributes);
                }
            }
        }
        libusb_free_config_descriptor(config);
    }
    return 0;
}

int main(void)
{
    libusb_context *context = NULL;
    libusb_device **devices = NULL;
    int rc = libusb_init_context(&context, NULL, 0);
    if (rc != LIBUSB_SUCCESS) {
        fprintf(stderr, "libusb initialization failed: %s\n", libusb_error_name(rc));
        return EXIT_FAILURE;
    }

    ssize_t count = libusb_get_device_list(context, &devices);
    if (count < 0) {
        fprintf(stderr, "USB enumeration failed: %s\n", libusb_error_name((int)count));
        libusb_exit(context);
        return EXIT_FAILURE;
    }

    int found = 0;
    int failed = 0;
    for (ssize_t index = 0; index < count; ++index) {
        struct libusb_device_descriptor descriptor;
        rc = libusb_get_device_descriptor(devices[index], &descriptor);
        if (rc != LIBUSB_SUCCESS)
            continue;
        if (descriptor.idVendor != HP_VENDOR_ID ||
            descriptor.idProduct != SMART_TANK_500_PRODUCT_ID)
            continue;

        found = 1;
        failed |= print_device(devices[index], &descriptor);
    }

    libusb_free_device_list(devices, 1);
    libusb_exit(context);

    if (!found) {
        fprintf(stderr, "HP Smart Tank 500 (03f0:2b54) not found\n");
        return 2;
    }
    return failed ? EXIT_FAILURE : EXIT_SUCCESS;
}
