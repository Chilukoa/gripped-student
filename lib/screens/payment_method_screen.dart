import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:amplify_flutter/amplify_flutter.dart';
import '../services/payment_service.dart';

class PaymentMethodScreen extends StatefulWidget {
  const PaymentMethodScreen({super.key});

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  final PaymentService _paymentService = PaymentService();
  final CardEditController _cardController = CardEditController();
  
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _hasPaymentMethod = false;
  bool _showCardInput = false;
  bool _cardComplete = false;
  Map<String, dynamic>? _cardDetails;
  String? _error;
  String? _setupIntentClientSecret;
  String? _setupIntentId;

  @override
  void initState() {
    super.initState();
    _loadPaymentMethod();
  }

  @override
  void dispose() {
    _cardController.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentMethod() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _paymentService.getPaymentMethod();
      
      if (mounted) {
        setState(() {
          _hasPaymentMethod = result['hasPaymentMethod'] == true;
          _cardDetails = result['card'] as Map<String, dynamic>?;
          _isLoading = false;
        });
      }
    } catch (e) {
      safePrint('PaymentMethodScreen: Error loading payment method: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startAddPaymentMethod() async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      safePrint('PaymentMethodScreen: Creating setup intent...');
      final setupIntentResult = await _paymentService.createSetupIntent();
      
      if (mounted) {
        setState(() {
          _setupIntentClientSecret = setupIntentResult['clientSecret'] as String;
          _setupIntentId = setupIntentResult['setupIntentId'] as String;
          _showCardInput = true;
          _isProcessing = false;
        });
      }
      safePrint('PaymentMethodScreen: Setup intent created successfully');
    } catch (e) {
      safePrint('PaymentMethodScreen: Error creating setup intent: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmPaymentMethod() async {
    if (_setupIntentClientSecret == null || !_cardComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid card details'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      safePrint('PaymentMethodScreen: Confirming setup intent...');
      
      final setupIntent = await Stripe.instance.confirmSetupIntent(
        paymentIntentClientSecret: _setupIntentClientSecret!,
        params: const PaymentMethodParams.card(paymentMethodData: PaymentMethodData()),
      );

      safePrint('PaymentMethodScreen: Setup intent confirmed, status: ${setupIntent.status}');

      // SetupIntent status can be PaymentIntentsStatus.Succeeded or the string "Succeeded"
      final isSucceeded = setupIntent.status == PaymentIntentsStatus.Succeeded || 
                          setupIntent.status.toString().toLowerCase().contains('succeeded');

      if (isSucceeded) {
        final confirmResult = await _paymentService.confirmSetupIntent(
          setupIntentId: _setupIntentId!,
          paymentMethodId: setupIntent.paymentMethodId,
        );

        if (confirmResult['success'] == true && mounted) {
          setState(() {
            _hasPaymentMethod = true;
            _cardDetails = confirmResult['card'] as Map<String, dynamic>?;
            _showCardInput = false;
            _isProcessing = false;
            _setupIntentClientSecret = null;
            _setupIntentId = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment method saved successfully!'), backgroundColor: Colors.green),
          );
        }
      } else {
        throw Exception('Setup failed with status: ${setupIntent.status}');
      }
    } on StripeException catch (e) {
      safePrint('PaymentMethodScreen: Stripe exception: ${e.error.localizedMessage}');
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.error.localizedMessage ?? 'Payment setup failed'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      safePrint('PaymentMethodScreen: Error: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _cancelAddPaymentMethod() {
    setState(() {
      _showCardInput = false;
      _setupIntentClientSecret = null;
      _setupIntentId = null;
      _cardComplete = false;
    });
  }

  Future<void> _removePaymentMethod() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Payment Method'),
        content: const Text('Are you sure you want to remove your payment method? You will need to add a new one before booking classes.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);

    try {
      await _paymentService.deletePaymentMethod();
      if (mounted) {
        setState(() {
          _hasPaymentMethod = false;
          _cardDetails = null;
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment method removed successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      safePrint('PaymentMethodScreen: Error removing payment method: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing payment method: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getCardBrandDisplay(String? brand) {
    switch (brand?.toLowerCase()) {
      case 'visa': return '💳 Visa';
      case 'mastercard': return '💳 Mastercard';
      case 'amex':
      case 'american_express': return '💳 Amex';
      case 'discover': return '💳 Discover';
      default: return '💳 Card';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Method'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple)))
          : SingleChildScrollView(
              padding: EdgeInsets.all(screenWidth * 0.04),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Manage Payment Method', style: TextStyle(fontSize: screenWidth * 0.06, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                  SizedBox(height: screenHeight * 0.01),
                  Text('Add or update your payment method to book fitness classes.', style: TextStyle(fontSize: screenWidth * 0.04, color: Colors.grey[600])),
                  SizedBox(height: screenHeight * 0.03),
                  if (!_showCardInput) _buildCurrentPaymentCard(screenWidth, screenHeight),
                  if (_showCardInput) _buildCardInputSection(screenWidth, screenHeight),
                  SizedBox(height: screenHeight * 0.03),
                  if (!_showCardInput) _buildActionButtons(screenWidth, screenHeight),
                  SizedBox(height: screenHeight * 0.04),
                  _buildSecurityInfo(screenWidth, screenHeight),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentPaymentCard(double screenWidth, double screenHeight) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _hasPaymentMethod ? Icons.credit_card : Icons.credit_card_off,
                  color: _hasPaymentMethod ? Colors.deepPurple : Colors.grey,
                  size: screenWidth * 0.08,
                ),
                SizedBox(width: screenWidth * 0.03),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_hasPaymentMethod ? 'Payment Method on File' : 'No Payment Method', style: TextStyle(fontSize: screenWidth * 0.045, fontWeight: FontWeight.bold)),
                      if (_hasPaymentMethod && _cardDetails != null) ...[
                        SizedBox(height: screenHeight * 0.005),
                        Text('${_getCardBrandDisplay(_cardDetails!['brand'])} •••• ${_cardDetails!['last4']}', style: TextStyle(fontSize: screenWidth * 0.04, color: Colors.grey[700])),
                        Text('Expires ${_cardDetails!['expMonth']}/${_cardDetails!['expYear']}', style: TextStyle(fontSize: screenWidth * 0.035, color: Colors.grey[600])),
                      ],
                    ],
                  ),
                ),
                if (_hasPaymentMethod)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)),
                    child: const Text('ACTIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            if (!_hasPaymentMethod) ...[
              SizedBox(height: screenHeight * 0.02),
              Container(
                padding: EdgeInsets.all(screenWidth * 0.03),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange, size: screenWidth * 0.05),
                    SizedBox(width: screenWidth * 0.02),
                    Expanded(child: Text('You need to add a payment method before you can book classes.', style: TextStyle(fontSize: screenWidth * 0.035, color: Colors.orange[800]))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCardInputSection(double screenWidth, double screenHeight) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter Card Details', style: TextStyle(fontSize: screenWidth * 0.045, fontWeight: FontWeight.bold)),
            SizedBox(height: screenHeight * 0.02),
            CardField(
              controller: _cardController,
              onCardChanged: (card) => setState(() => _cardComplete = card?.complete ?? false),
              decoration: InputDecoration(
                labelText: 'Card',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.deepPurple)),
              ),
            ),
            SizedBox(height: screenHeight * 0.02),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing ? null : _cancelAddPaymentMethod,
                    style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: screenHeight * 0.015), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: const Text('Cancel'),
                  ),
                ),
                SizedBox(width: screenWidth * 0.03),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_isProcessing || !_cardComplete) ? null : _confirmPaymentMethod,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: screenHeight * 0.015), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: _isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : const Text('Save Card'),
                  ),
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.015),
            Container(
              padding: EdgeInsets.all(screenWidth * 0.03),
              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: screenWidth * 0.05),
                  SizedBox(width: screenWidth * 0.02),
                  Expanded(child: Text('Test card: 4242 4242 4242 4242, any future date, any CVC', style: TextStyle(fontSize: screenWidth * 0.032, color: Colors.blue[800]))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(double screenWidth, double screenHeight) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : _startAddPaymentMethod,
            icon: _isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : Icon(_hasPaymentMethod ? Icons.edit : Icons.add),
            label: Text(_isProcessing ? 'Processing...' : _hasPaymentMethod ? 'Update Payment Method' : 'Add Payment Method'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          ),
        ),
        if (_hasPaymentMethod) ...[
          SizedBox(height: screenHeight * 0.015),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isProcessing ? null : _removePaymentMethod,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove Payment Method'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSecurityInfo(double screenWidth, double screenHeight) {
    return Card(
      color: Colors.grey[100],
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_outline, color: Colors.grey[700], size: screenWidth * 0.05),
                SizedBox(width: screenWidth * 0.02),
                Text('Secure Payment', style: TextStyle(fontSize: screenWidth * 0.04, fontWeight: FontWeight.bold, color: Colors.grey[800])),
              ],
            ),
            SizedBox(height: screenHeight * 0.01),
            Text('Your payment information is securely processed by Stripe. We never store your full card details on our servers.', style: TextStyle(fontSize: screenWidth * 0.035, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}
