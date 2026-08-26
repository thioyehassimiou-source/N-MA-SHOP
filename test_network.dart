// ignore_for_file: avoid_print
import 'dart:io';

void main() async {
  final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4, includeLoopback: false);
  for (var interface in interfaces) {
    print('Interface: ${interface.name}');
    for (var addr in interface.addresses) {
      print('  Addr: ${addr.address}');
    }
  }
}
