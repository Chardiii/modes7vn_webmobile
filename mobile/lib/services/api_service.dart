import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config.dart';

const String kBaseUrl = AppConfig.baseUrl;

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final _storage = const FlutterSecureStorage();
  late final Dio _dio = Dio(BaseOptions(
    baseUrl: kBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ))
    ..interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));

  Future<void> saveToken(String token) =>
      _storage.write(key: 'access_token', value: token);
  Future<void> clearToken() => _storage.delete(key: 'access_token');
  Future<bool> get isLoggedIn async =>
      (await _storage.read(key: 'access_token')) != null;

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await _dio.post('/auth/login',
        data: {'username': username, 'password': password});
    await saveToken(res.data['access_token']);
    return res.data;
  }

  Future<Map<String, dynamic>> googleLogin({
    String? idToken,
    String? accessToken,
  }) async {
    final res = await _dio.post('/auth/google', data: {
      'id_token': ?idToken,
      'access_token': ?accessToken,
    });
    await saveToken(res.data['access_token']);
    return res.data;
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    String role = 'buyer',
    String firstName = '',
    String lastName = '',
    String phone = '',
    String shopName = '',
    String shopDescription = '',
    String vehicleType = '',
    String plateNumber = '',
    String? validIdPath,
    String? businessPermitPath,
    String? driversLicensePath,
  }) async {
    final formData = FormData.fromMap({
      'username': username,
      'email': email,
      'password': password,
      'role': role,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      if (shopName.isNotEmpty) 'shop_name': shopName,
      if (shopDescription.isNotEmpty) 'shop_description': shopDescription,
      if (vehicleType.isNotEmpty) 'vehicle_type': vehicleType,
      if (plateNumber.isNotEmpty) 'plate_number': plateNumber,
      if (validIdPath != null)
        'valid_id': await MultipartFile.fromFile(validIdPath,
            filename: validIdPath.split('/').last),
      if (businessPermitPath != null)
        'business_permit': await MultipartFile.fromFile(businessPermitPath,
            filename: businessPermitPath.split('/').last),
      if (driversLicensePath != null)
        'drivers_license': await MultipartFile.fromFile(driversLicensePath,
            filename: driversLicensePath.split('/').last),
    });
    final res = await _dio.post('/auth/register',
        data: formData,
        options: Options(contentType: 'multipart/form-data'));
    return res.data;
  }

  Future<Map<String, dynamic>> getMe() async {
    final res = await _dio.get('/auth/me');
    return res.data;
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final res = await _dio.put('/auth/profile', data: data);
    return res.data;
  }

  // ── Products ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getProducts({
    int page = 1,
    String search = '',
    String category = '',
    String sort = 'newest',
  }) async {
    final res = await _dio.get('/products', queryParameters: {
      'page': page,
      if (search.isNotEmpty) 'search': search,
      if (category.isNotEmpty) 'category': category,
      'sort': sort,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> getProduct(int id) async {
    final res = await _dio.get('/products/$id');
    return res.data;
  }

  Future<void> submitReview(int productId,
      {required int rating, String comment = '', int? orderId}) async {
    await _dio.post('/products/$productId/reviews', data: {
      'rating': rating,
      'comment': comment,
      'order_id': ?orderId,
    });
  }

  // ── Wishlist ──────────────────────────────────────────────────────────────

  Future<List<dynamic>> getWishlist() async {
    final res = await _dio.get('/wishlist');
    return res.data;
  }

  Future<String> toggleWishlist(int productId) async {
    final res = await _dio.post('/wishlist/toggle/$productId');
    return res.data['status'];
  }

  // ── Cart ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getCart() async {
    final res = await _dio.get('/cart');
    return res.data;
  }

  Future<void> addToCart(int productId,
      {int? variantId, int quantity = 1}) async {
    await _dio.post('/cart/add', data: {
      'product_id': productId,
      'variant_id': variantId,
      'quantity': quantity,
    });
  }

  Future<void> updateCartQty(int productId,
      {int? variantId, required int quantity}) async {
    await _dio.post('/cart/update', data: {
      'product_id': productId,
      'variant_id': variantId,
      'quantity': quantity,
    });
  }

  Future<void> removeFromCart(int productId, {int? variantId}) async {
    await _dio.post('/cart/remove',
        data: {'product_id': productId, 'variant_id': variantId});
  }

  // ── Orders ────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getOrders() async {
    final res = await _dio.get('/orders');
    return res.data;
  }

  Future<Map<String, dynamic>> getOrder(int id) async {
    final res = await _dio.get('/orders/$id');
    return res.data;
  }

  Future<Map<String, dynamic>> checkout({
    required String address,
    required String city,
    required String province,
    String zip = '',
    List<Map<String, dynamic>> selectedItems = const [],
    String paymentMethod = 'cod',
  }) async {
    final res = await _dio.post('/orders/checkout', data: {
      'delivery_address': address,
      'delivery_city': city,
      'delivery_province': province,
      'delivery_zip': zip,
      'payment_method': paymentMethod,
      if (selectedItems.isNotEmpty)
        'selected_items': selectedItems
            .map((i) => {
                  'product_id': i['product_id'],
                  'variant_id': i['variant_id'],
                })
            .toList(),
    });
    return res.data;
  }

  Future<Map<String, dynamic>> estimateShipping({
    required int sellerId,
    required String deliveryCity,
    required String deliveryProvince,
  }) async {
    final res = await _dio.post('/shipping/estimate', data: {
      'seller_id': sellerId,
      'delivery_city': deliveryCity,
      'delivery_province': deliveryProvince,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> createPaymentLink(int orderId) async {
    final res = await _dio.post('/payments/create-link',
        data: {'order_id': orderId});
    return res.data;
  }

  Future<Map<String, dynamic>> verifyPayment(int orderId) async {
    final res = await _dio.get('/payments/verify/$orderId');
    return res.data;
  }

  Future<Map<String, dynamic>> cancelOrder(int orderId,
      {required String reason}) async {
    final res = await _dio.post('/orders/$orderId/cancel',
        data: {'reason': reason});
    return res.data;
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  Future<List<dynamic>> getInbox() async {
    final res = await _dio.get('/messages');
    return res.data;
  }

  Future<List<dynamic>> getThread(int partnerId) async {
    final res = await _dio.get('/messages/$partnerId');
    return res.data;
  }

  Future<Map<String, dynamic>> sendMessage(int partnerId, String body,
      {int? productId, int? orderId}) async {
    final res = await _dio.post('/messages/$partnerId', data: {
      'body': body,
      'product_id': productId,
      'order_id': orderId,
    });
    return res.data;
  }

  Future<int> getUnreadCount() async {
    final res = await _dio.get('/messages/unread');
    return res.data['count'] ?? 0;
  }

  // ── Seller ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getSellerDashboard() async {
    final res = await _dio.get('/seller/dashboard');
    return res.data;
  }

  Future<List<dynamic>> getSellerOrders({String status = ''}) async {
    final res = await _dio.get('/seller/orders',
        queryParameters: {if (status.isNotEmpty) 'status': status});
    return res.data;
  }

  Future<Map<String, dynamic>> verifyOrder(int orderId) async {
    final res = await _dio.post('/seller/orders/$orderId/verify');
    return res.data;
  }

  Future<Map<String, dynamic>> approveCancelOrder(int orderId) async {
    final res = await _dio.post('/orders/$orderId/approve-cancel');
    return res.data;
  }

  Future<Map<String, dynamic>> rejectCancelOrder(int orderId) async {
    final res = await _dio.post('/orders/$orderId/reject-cancel');
    return res.data;
  }

  Future<List<dynamic>> getSellerProducts() async {
    final res = await _dio.get('/seller/products');
    return res.data;
  }

  Future<bool> toggleSellerProduct(int productId) async {
    final res = await _dio.post('/seller/products/$productId/toggle');
    return res.data['is_active'];
  }

  Future<Map<String, dynamic>> addProduct({
    required String name,
    required double price,
    required String category,
    String description = '',
    int stock = 0,
    List<String> imagePaths = const [],
    List<Map<String, dynamic>> variants = const [],
  }) async {
    final formData = FormData.fromMap({
      'name': name,
      'price': price.toString(),
      'category': category,
      'description': description,
      if (variants.isEmpty) 'stock': stock.toString(),
      for (int i = 0; i < variants.length; i++) ...{
        'variant_size[]': variants[i]['size'] ?? '',
        'variant_color[]': variants[i]['color'] ?? '',
        'variant_stock[]': (variants[i]['stock'] ?? 0).toString(),
        'variant_price_adj[]': (variants[i]['price_adj'] ?? 0).toString(),
      },
      'images': [
        for (final path in imagePaths)
          await MultipartFile.fromFile(path, filename: path.split('/').last)
      ],
    });
    final res = await _dio.post('/seller/products/add',
        data: formData,
        options: Options(contentType: 'multipart/form-data'));
    return res.data;
  }

  Future<Map<String, dynamic>> getSellerProductForEdit(int productId) async {
    final res = await _dio.get('/seller/products/$productId/edit');
    return res.data;
  }

  Future<Map<String, dynamic>> editProduct({
    required int productId,
    required String name,
    required double price,
    required String category,
    String description = '',
    int stock = 0,
    List<String> newImagePaths = const [],
    List<int> removeImageIds = const [],
    List<Map<String, dynamic>> variants = const [],
  }) async {
    final formData = FormData.fromMap({
      'name': name,
      'price': price.toString(),
      'category': category,
      'description': description,
      if (variants.isEmpty) 'stock': stock.toString(),
      'remove_image_ids': removeImageIds.map((id) => id.toString()).toList(),
      for (int i = 0; i < variants.length; i++) ...{
        'variant_id[]': (variants[i]['id'] ?? '').toString(),
        'variant_size[]': variants[i]['size'] ?? '',
        'variant_color[]': variants[i]['color'] ?? '',
        'variant_stock[]': (variants[i]['stock'] ?? 0).toString(),
        'variant_price_adj[]': (variants[i]['price_adj'] ?? 0).toString(),
      },
      'images': [
        for (final path in newImagePaths)
          await MultipartFile.fromFile(path, filename: path.split('/').last)
      ],
    });
    final res = await _dio.post('/seller/products/$productId/edit',
        data: formData,
        options: Options(contentType: 'multipart/form-data'));
    return res.data;
  }

  Future<List<dynamic>> getCategories() async {
    final res = await _dio.get('/products/categories');
    return res.data;
  }

  // ── Rider ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getRiderOrders() async {
    final res = await _dio.get('/rider/orders');
    return res.data;
  }

  Future<Map<String, dynamic>> claimOrder(int orderId) async {
    final res = await _dio.post('/rider/orders/$orderId/claim');
    return res.data;
  }

  Future<Map<String, dynamic>> pickupOrder(int orderId) async {
    final res = await _dio.post('/rider/orders/$orderId/pickup');
    return res.data;
  }

  Future<Map<String, dynamic>> deliverOrder(int orderId,
      {required String proofImagePath}) async {
    final formData = FormData.fromMap({
      'proof_of_delivery': await MultipartFile.fromFile(
        proofImagePath,
        filename: proofImagePath.split('/').last,
      ),
    });
    final res = await _dio.post(
      '/rider/orders/$orderId/deliver',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return res.data;
  }
}
