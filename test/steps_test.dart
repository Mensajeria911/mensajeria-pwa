import 'package:flutter_test/flutter_test.dart';
import 'package:mensajeria_911_driver/models.dart';

Map<String, dynamic> step(String key, String kind, String title) => {
  'key': key,
  'kind': kind,
  'title': title,
  'detail': '',
  'status': 'pending',
};

List<String> keysFor(String type, List<Map<String, dynamic>> plan) {
  final service = CourierService.fromMap({
    'id': '1',
    'code': 'FN155001',
    'service_type': type,
    'status': 'assigned',
    'branch_code': '155',
    'payment_method': 'cash',
    'route_plan': plan,
  });
  return service.steps(Branch.unknown('155'), null).map((s) => s.key).toList();
}

void main() {
  final origin = step('origin', 'pickup', 'Recoger pedido en FN155');
  final cross = step('cross-1', 'cross', 'Recoger cruce en FN145 para FN155');
  final buy = step('buy-1', 'buy', 'Comprar: producto');
  final delivery = step('delivery', 'deliver', 'Entregar al cliente');
  final crossReturn = step('cross-return', 'deliver', 'Entregar los cruces en FN155');
  final buyReturn = step('return-origin', 'deliver', 'Regresar con la compra');

  test('cruce publicado antes queda en dos pasos', () {
    expect(keysFor('cross', [origin, cross, crossReturn]), ['cross-1', 'cross-return']);
  });
  test('compra sola', () {
    expect(keysFor('buy', [origin, buy, buyReturn]), ['buy-1', 'return-origin']);
  });
  test('domicilio con cruce', () {
    expect(keysFor('home_cross', [origin, cross, crossReturn, delivery]), ['cross-1', 'origin', 'delivery']);
  });
  test('domicilio con compra', () {
    expect(keysFor('home_buy', [origin, buy, buyReturn, delivery]), ['buy-1', 'origin', 'delivery']);
  });
  test('domicilio con compra y cruce', () {
    expect(keysFor('home_buy_cross', [origin, buy, cross, delivery]), ['cross-1', 'buy-1', 'origin', 'delivery']);
  });
}
