const List<Map<String, String>> trustedDomains = [
  { "name": "Stripe", "domain": "stripe.com" },
  { "name": "PayPal", "domain": "paypal.com" },
  { "name": "Square", "domain": "squareup.com" },
  { "name": "Adyen", "domain": "adyen.com" },
  { "name": "Authorize.Net", "domain": "authorize.net" },
  { "name": "2Checkout (Verifone)", "domain": "2checkout.com" },
  { "name": "Braintree", "domain": "braintreepayments.com" },
  { "name": "Amazon Pay", "domain": "pay.amazon.com" },
  { "name": "Apple Pay", "domain": "apple.com" },
  { "name": "Google Pay", "domain": "pay.google.com" },
  { "name": "Worldpay", "domain": "worldpay.com" },
  { "name": "Klarna", "domain": "klarna.com" },
  { "name": "Checkout.com", "domain": "checkout.com" },
  { "name": "BlueSnap", "domain": "bluesnap.com" },
  { "name": "Mollie", "domain": "mollie.com" },
  { "name": "Razorpay", "domain": "razorpay.com" },
  { "name": "Paytm", "domain": "paytm.com" },
  { "name": "PhonePe", "domain": "phonepe.com" },
  { "name": "CCAvenue", "domain": "ccavenue.com" },
  { "name": "Instamojo", "domain": "instamojo.com" },
  { "name": "JusPay", "domain": "juspay.in" },
  { "name": "Cashfree", "domain": "cashfree.com" },
  { "name": "BillDesk", "domain": "billdesk.com" },
  { "name": "PayU India", "domain": "payu.in" },
  { "name": "Mercado Pago", "domain": "mercadopago.com" },
  { "name": "iDEAL", "domain": "ideal.nl" },
  { "name": "Payoneer", "domain": "payoneer.com" },
  { "name": "Alipay", "domain": "intl.alipay.com" },
  { "name": "WeChat Pay", "domain": "pay.weixin.qq.com" }
];
bool isTrustedPaymentDomain(String url) {
  return trustedDomains.any((gateway) => url.contains(gateway['domain']!));
}