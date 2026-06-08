import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/auth_service.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../providers/wishlist_provider.dart';
import 'home_screen.dart';

class AuthParentPage extends StatefulWidget {
  const AuthParentPage({super.key});

  @override
  State<AuthParentPage> createState() => _AuthParentPageState();
}

class _AuthParentPageState extends State<AuthParentPage>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController    = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController    = TextEditingController();
  final TextEditingController _otpController      = TextEditingController();

  // 'login' | 'signup' | 'forgot' | 'otp'
  String _currentView    = 'login';
  // 'login' | 'signup' — tracks the mode when the OTP view is active
  String _otpMode        = 'login';

  bool   _isLoading       = false;
  bool   _obscurePassword = true;
  bool   _otpSent         = false;
  String _otpPhone        = '';

  late AnimationController _fadeController;
  late Animation<double>   _fadeAnimation;

  static const Color _dark        = Color(0xFF0A0F1E);
  static const Color _teal        = Color(0xFF0D9488);
  static const Color _green       = Color(0xFF22C55E);
  static const Color _textGrey    = Color(0xFF64748B);
  static const Color _borderColor = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnimation = CurvedAnimation(
        parent: _fadeController, curve: Curves.easeInOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _switchView(String view, {String otpMode = 'login'}) {
    _fadeController.reverse().then((_) {
      setState(() {
        _currentView = view;
        _otpMode     = otpMode;
        _otpSent     = false;
        _otpController.clear();
        _phoneController.clear();
      });
      _fadeController.forward();
    });
  }

  /// Kick off all providers after a successful login/signup.
  Future<void> _initProviders() async {
    if (!mounted) return;
    context.read<ProductProvider>().loadHomeData();
    context.read<WishlistProvider>().loadIds();
    await Future.wait([
      context.read<AuthProvider>().loadUser(),
      context.read<CartProvider>().loadCart(),
    ]);
  }

  // ── Google sign-in: mode-aware ────────────────────────────────
  // signInWithGoogle() returns:
  //   String → explicit error (backend rejected, Firebase error, etc.)
  //   null   → EITHER user cancelled picker (no tokens saved)
  //            OR success (tokens saved by _exchangeFirebaseToken)
  // We distinguish by checking isLoggedIn AFTER the call.
  Future<void> _handleGoogleSignIn() async {
    final mode = (_currentView == 'signup' || _otpMode == 'signup')
        ? 'signup'
        : 'login';

    setState(() => _isLoading = true);
    final error = await _authService.signInWithGoogle(mode: mode);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      // Explicit error from Firebase or backend
      _showSnackBar(error, Colors.redAccent);
      return;
    }

    // null return: distinguish cancelled vs. success via token presence
    final loggedIn = await _authService.isLoggedIn;
    if (!loggedIn) return; // user dismissed Google picker — do nothing

    _showSnackBar(
        mode == 'signup' ? 'Welcome to Savaan!' : 'Welcome back!', _teal);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      await _initProviders();
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  // ── Send OTP ──────────────────────────────────────────────────
  Future<void> _handleSendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      _showSnackBar('Enter a valid 10-digit mobile number', Colors.redAccent);
      return;
    }
    setState(() => _isLoading = true);
    final fullPhone = '+91$phone';
    final error = await _authService.sendPhoneOtp(phone: fullPhone);
    setState(() => _isLoading = false);
    if (error != null) {
      _showSnackBar(error, Colors.redAccent);
    } else {
      setState(() { _otpSent = true; _otpPhone = fullPhone; });
      _showSnackBar('OTP sent to $fullPhone', _teal);
    }
  }

  // ── Verify OTP: mode-aware ────────────────────────────────────
  Future<void> _handleVerifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      _showSnackBar('Enter the 6-digit OTP', Colors.redAccent);
      return;
    }
    setState(() => _isLoading = true);
    final error = await _authService.verifyPhoneOtp(
        phone: _otpPhone, otp: otp, mode: _otpMode);
    setState(() => _isLoading = false);
    if (error != null) {
      _showSnackBar(error, Colors.redAccent);
    } else {
      _showSnackBar(
          _otpMode == 'signup' ? 'Welcome to Savaan!' : 'Welcome back!', _teal);
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        await _initProviders();
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    }
  }

  // ── Email login / signup / forgot ─────────────────────────────
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    String? error;

    if (_currentView == 'login') {
      error = await _authService.loginWithEmail(
        email:    _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (error == null) {
        _showSnackBar('Welcome back!', _teal);
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          await _initProviders();
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
      }
    } else if (_currentView == 'signup') {
      error = await _authService.signUpWithEmail(
        email:    _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (error == null) {
        _showSnackBar('Welcome to Savaan!', _teal);
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          await _initProviders();
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
      }
    } else if (_currentView == 'forgot') {
      error = await _authService.resetPassword(
          email: _emailController.text.trim());
      if (error == null) {
        _showSnackBar('Password reset link sent!', Colors.blue);
      }
    }

    setState(() => _isLoading = false);
    if (error != null) _showSnackBar(error, Colors.redAccent);
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: _currentView == 'otp' ? _buildOtpView() : _buildMainView(),
      ),
    );
  }

  // ── Main view (login / signup / forgot) ───────────────────────
  Widget _buildMainView() {
    final isLogin  = _currentView == 'login';
    final isSignup = _currentView == 'signup';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!isLogin)
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => _switchView('login'),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: _borderColor),
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white.withValues(alpha: .8),
                    ),
                    child: const Icon(Icons.arrow_back, size: 20, color: _dark),
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Logo
            Image.asset('assets/logo.png', height: 90,
                errorBuilder: (_, __, ___) => Container(
                  height: 90, width: 90,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_teal, _green],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.diamond_outlined,
                      size: 44, color: Colors.white),
                )),
            const SizedBox(height: 10),

            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF22C55E)],
                begin: Alignment.centerLeft, end: Alignment.centerRight,
              ).createShader(bounds),
              blendMode: BlendMode.srcIn,
              child: const Text('S A V A A N',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                      letterSpacing: 6, color: Colors.white)),
            ),
            const SizedBox(height: 4),
            const Text('Luxury & Trust',
                style: TextStyle(fontSize: 13, color: _textGrey, letterSpacing: 1.5)),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 40, height: 1, color: _borderColor),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.diamond, size: 10, color: _teal)),
              Container(width: 40, height: 1, color: _borderColor),
            ]),
            const SizedBox(height: 28),

            Text(
              isLogin  ? 'Welcome Back'   :
              isSignup ? 'Create Account' : 'Reset Password',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold,
                  color: _dark),
            ),
            const SizedBox(height: 6),
            Text(
              isLogin  ? 'Sign in to continue your luxury shopping' :
              isSignup ? 'Join the Savaan luxury experience'        :
                         'We\'ll send a reset link to your email',
              style: const TextStyle(fontSize: 13, color: _textGrey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            _buildInputField(
              controller: _emailController,
              hint: 'Email Address',
              icon: Icons.email_outlined,
              validator: (val) =>
                  val == null || !val.contains('@') ? 'Enter a valid email' : null,
            ),

            if (_currentView != 'forgot') ...[
              const SizedBox(height: 14),
              _buildPasswordField(),
            ],

            if (isLogin) ...[
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _switchView('forgot'),
                  child: const Text('Forgot Password?',
                      style: TextStyle(color: _teal, fontSize: 13)),
                ),
              ),
            ] else
              const SizedBox(height: 20),

            _buildGradientButton(
              label: isLogin   ? 'LOGIN'           :
                     isSignup  ? 'REGISTER'        :
                                 'SEND RESET LINK',
              onTap: _isLoading ? null : _handleSubmit,
            ),

            const SizedBox(height: 20),

            Row(children: [
              const Expanded(child: Divider(color: _borderColor)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('OR',
                    style: TextStyle(color: _textGrey.withValues(alpha: .7),
                        fontSize: 12)),
              ),
              const Expanded(child: Divider(color: _borderColor)),
            ]),
            const SizedBox(height: 16),

            // ── Google button ──────────────────────────────────
            // LOGIN view  → "Continue with Google" (login mode, no new account)
            // SIGNUP view → "Continue with Google" (signup mode, creates account)
            _buildOutlineButton(
              label: isSignup ? 'Sign up with Google' : 'Continue with Google',
              icon: _googleIcon(),
              onTap: _isLoading ? () {} : _handleGoogleSignIn,
            ),
            const SizedBox(height: 12),

            // ── Mobile buttons ─────────────────────────────────
            if (isLogin)
              _buildOutlineButton(
                label: 'Login with Mobile Number',
                icon: const Icon(Icons.phone_outlined, size: 20, color: _dark),
                onTap: () => _switchView('otp', otpMode: 'login'),
              ),
            if (isSignup)
              _buildOutlineButton(
                label: 'Sign up with Mobile Number',
                icon: const Icon(Icons.phone_outlined, size: 20, color: _dark),
                onTap: () => _switchView('otp', otpMode: 'signup'),
              ),

            const SizedBox(height: 24),

            GestureDetector(
              onTap: () => _switchView(isLogin ? 'signup' : 'login'),
              child: RichText(
                text: TextSpan(
                  text: isLogin ? "Don't have an account?  " : "Already have an account?  ",
                  style: const TextStyle(color: _textGrey, fontSize: 14),
                  children: [
                    TextSpan(
                      text: isLogin ? 'Sign Up' : 'Login',
                      style: const TextStyle(color: _teal, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),
            _buildTrustBadges(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── OTP view (login or signup with mobile) ────────────────────
  Widget _buildOtpView() {
    final isSignupMode = _otpMode == 'signup';
    final title        = isSignupMode ? 'Sign Up with Mobile' : 'Login with Mobile';
    final subtitle     = isSignupMode
        ? 'Create your account with OTP'
        : 'Verify your mobile number to sign in';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => _switchView(isSignupMode ? 'signup' : 'login'),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: _borderColor),
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white.withValues(alpha: .8),
                ),
                child: const Icon(Icons.arrow_back, size: 20, color: _dark),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Mode badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: (isSignupMode
                      ? const Color(0xFF6366F1)
                      : _teal)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (isSignupMode
                        ? const Color(0xFF6366F1)
                        : _teal)
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              isSignupMode ? '✦ NEW ACCOUNT' : '✦ SIGN IN',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSignupMode ? const Color(0xFF6366F1) : _teal,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 16),

          Image.asset('assets/logo.png', height: 80,
              errorBuilder: (_, __, ___) => Container(
                height: 80, width: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_teal, _green]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.diamond_outlined,
                    size: 40, color: Colors.white),
              )),
          const SizedBox(height: 8),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF0D9488), Color(0xFF22C55E)],
              begin: Alignment.centerLeft, end: Alignment.centerRight,
            ).createShader(bounds),
            blendMode: BlendMode.srcIn,
            child: const Text('S A V A A N',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                    letterSpacing: 6, color: Colors.white)),
          ),
          const SizedBox(height: 4),
          const Text('Luxury & Trust',
              style: TextStyle(fontSize: 12, color: _textGrey, letterSpacing: 1.5)),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 40, height: 1, color: _borderColor),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.diamond, size: 10, color: _teal)),
            Container(width: 40, height: 1, color: _borderColor),
          ]),
          const SizedBox(height: 28),

          Text(title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                  color: _dark)),
          const SizedBox(height: 8),
          Text(subtitle,
              style: const TextStyle(fontSize: 13, color: _textGrey),
              textAlign: TextAlign.center),
          const SizedBox(height: 28),

          // Phone input
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: _borderColor),
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFFF8FAFC).withValues(alpha: .9),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: _borderColor))),
                child: const Row(children: [
                  Text('🇮🇳', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 6),
                  Text('+91', style: TextStyle(fontWeight: FontWeight.w600, color: _dark)),
                  SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down, size: 18, color: _textGrey),
                ]),
              ),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    hintText: 'Enter Mobile Number',
                    hintStyle: TextStyle(color: Color(0xFFCBD5E1)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // OTP field (shown after OTP is sent)
          if (_otpSent) ...[
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: _borderColor),
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFFF8FAFC).withValues(alpha: .9),
              ),
              child: TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold,
                    letterSpacing: 12, color: _dark),
                decoration: const InputDecoration(
                  hintText: '------',
                  hintStyle: TextStyle(color: Color(0xFFCBD5E1), letterSpacing: 12),
                  border: InputBorder.none,
                  counterText: '',
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildGradientButton(
              label: isSignupMode ? 'VERIFY & CREATE ACCOUNT' : 'VERIFY & LOGIN',
              onTap: _isLoading ? null : _handleVerifyOtp,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _isLoading ? null : () => setState(() {
                _otpSent = false;
                _otpController.clear();
              }),
              child: const Text('Resend OTP',
                  style: TextStyle(color: _teal)),
            ),
          ] else
            _buildGradientButton(
              label: 'SEND OTP',
              onTap: _isLoading ? null : _handleSendOtp,
            ),

          const SizedBox(height: 20),

          Row(children: [
            const Expanded(child: Divider(color: _borderColor)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('OR',
                  style: TextStyle(
                      color: _textGrey.withValues(alpha: .7), fontSize: 12)),
            ),
            const Expanded(child: Divider(color: _borderColor)),
          ]),
          const SizedBox(height: 16),

          _buildOutlineButton(
            label: isSignupMode ? 'Sign up with Google' : 'Continue with Google',
            icon: _googleIcon(),
            onTap: _isLoading ? () {} : _handleGoogleSignIn,
          ),

          const SizedBox(height: 20),

          GestureDetector(
            onTap: () => _switchView(isSignupMode ? 'login' : 'signup'),
            child: RichText(
              text: TextSpan(
                text: isSignupMode
                    ? 'Already have an account?  '
                    : "Don't have an account?  ",
                style: const TextStyle(color: _textGrey, fontSize: 14),
                children: [
                  TextSpan(
                    text: isSignupMode ? 'Login' : 'Sign Up',
                    style: const TextStyle(color: _teal, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),
          _buildTrustBadges(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Shared widgets ────────────────────────────────────────────
  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: const TextStyle(color: _dark, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14),
        prefixIcon: Icon(icon, color: _textGrey, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC).withValues(alpha: .9),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _borderColor)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _borderColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _teal, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.redAccent)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: const TextStyle(color: _dark, fontSize: 14),
      validator: (val) => val == null || val.length < 6 ? 'Min 6 characters' : null,
      decoration: InputDecoration(
        hintText: 'Password',
        hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14),
        prefixIcon: const Icon(Icons.lock_outline, color: _textGrey, size: 20),
        suffixIcon: GestureDetector(
          onTap: () => setState(() => _obscurePassword = !_obscurePassword),
          child: Icon(
            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: _textGrey, size: 20,
          ),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC).withValues(alpha: .9),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _borderColor)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _borderColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _teal, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.redAccent)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildGradientButton({required String label, required VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, height: 54,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: onTap == null
                ? [Colors.grey.shade400, Colors.grey.shade300]
                : const [_teal, _green],
            begin: Alignment.centerLeft, end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: onTap == null ? [] : [
            BoxShadow(color: _teal.withValues(alpha: .3),
                blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Center(
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
              : Text(label,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold,
                      fontSize: 15, letterSpacing: 1.5)),
        ),
      ),
    );
  }

  Widget _buildOutlineButton({
    required String label,
    required Widget icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, height: 52,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .8),
          border: Border.all(color: _borderColor, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          icon,
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: _dark,
              fontWeight: FontWeight.w600, fontSize: 14)),
        ]),
      ),
    );
  }

  Widget _googleIcon() {
    return SizedBox(
      width: 20, height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }

  Widget _buildTrustBadges() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC).withValues(alpha: .9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _trustBadge(Icons.verified_user_outlined, 'Secure\nLogin'),
        Container(width: 1, height: 36, color: _borderColor),
        _trustBadge(Icons.lock_outline, 'Trusted\nPlatform'),
        Container(width: 1, height: 36, color: _borderColor),
        _trustBadge(Icons.star_outline, '100% Safe &\nAuthentic'),
      ]),
    );
  }

  Widget _trustBadge(IconData icon, String label) {
    return Column(children: [
      Icon(icon, size: 22, color: _teal),
      const SizedBox(height: 6),
      Text(label, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: _textGrey,
              fontWeight: FontWeight.w500, height: 1.4)),
    ]);
  }
}

// ── Google Logo Painter ───────────────────────────────────────
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint  = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -0.5, 1.6, true, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), 1.1, 1.6, true, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), 2.7, 0.8, true, paint);
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), 3.5, 0.9, true, paint);

    paint.color = Colors.white;
    canvas.drawCircle(center, radius * 0.6, paint);
    canvas.drawRect(
      Rect.fromLTWH(center.dx, center.dy - radius * 0.2, radius * 0.95, radius * 0.4),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
