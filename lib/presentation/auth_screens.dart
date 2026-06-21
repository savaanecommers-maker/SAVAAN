import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/auth_service.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../providers/wishlist_provider.dart';
import '../data/deep_link_service.dart';
import '../providers/homepage_provider.dart';
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

  final TextEditingController _nameController        = TextEditingController();
  final TextEditingController _emailController       = TextEditingController();
  final TextEditingController _passwordController    = TextEditingController();
  final TextEditingController _otpController         = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  // 'login' | 'signup' | 'forgot' | 'reset'
  String _currentView    = 'login';

  bool   _isLoading       = false;
  bool   _obscurePassword = true;

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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  void _switchView(String view) {
    _fadeController.reverse().then((_) {
      setState(() => _currentView = view);
      _nameController.clear();
      _fadeController.forward();
    });
  }

  /// Kick off all providers after a successful login/signup.
  Future<void> _initProviders() async {
    if (!mounted) return;
    context.read<ProductProvider>().loadHomeData();
    context.read<WishlistProvider>().loadIds();
    context.read<HomepageProvider>().load();
    await Future.wait([
      context.read<AuthProvider>().loadUser(),
      context.read<CartProvider>().loadCart(),
    ]);
  }

  /// Navigate to HomeScreen after login; if a deep-link product is pending,
  /// HomeScreen._init() will push ProductDetailScreen on top automatically.
  void _navigateAfterLogin(NavigatorState nav) {
    nav.pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  Future<void> _handleGoogleSignIn() async {
    final mode = _currentView == 'signup' ? 'signup' : 'login';

    setState(() => _isLoading = true);
    final error = await _authService.signInWithGoogle(mode: mode);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      // Explicit error from backend
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
      final nav = Navigator.of(context);
      await _initProviders();
      _navigateAfterLogin(nav);
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
          final nav = Navigator.of(context);
          await _initProviders();
          _navigateAfterLogin(nav);
        }
      }
    } else if (_currentView == 'signup') {
      error = await _authService.signUpWithEmail(
        fullName: _nameController.text.trim(),
        email:    _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (error == null) {
        _showSnackBar('Welcome to Savaan!', _teal);
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          final nav = Navigator.of(context);
          await _initProviders();
          _navigateAfterLogin(nav);
        }
      }
    } else if (_currentView == 'forgot') {
      error = await _authService.resetPassword(
          email: _emailController.text.trim());
      if (error == null) {
        _showSnackBar('Code sent! Check your email.', Colors.blue);
        if (mounted) setState(() => _currentView = 'reset');
      }
    } else if (_currentView == 'reset') {
      error = await _authService.confirmPasswordReset(
        email:       _emailController.text.trim(),
        code:        _otpController.text.trim(),
        newPassword: _newPasswordController.text.trim(),
      );
      if (error == null) {
        _showSnackBar('Password reset! Please log in.', _teal);
        _otpController.clear();
        _newPasswordController.clear();
        if (mounted) setState(() => _currentView = 'login');
      }
    }

    if (mounted) setState(() => _isLoading = false);
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
        child: _buildMainView(),
      ),
    );
  }

  // ── Main view (login / signup / forgot) ───────────────────────
  Widget _buildMainView() {
    final isLogin  = _currentView == 'login';
    final isSignup = _currentView == 'signup';
    final isReset  = _currentView == 'reset';

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
            Image.asset('assets/logo.png', height: 120,
                errorBuilder: (_, _, _) => Container(
                  height: 120, width: 120,
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
            const SizedBox(height: 4),

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
              isSignup ? 'Create Account' :
              isReset  ? 'Enter Reset Code' : 'Reset Password',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold,
                  color: _dark),
            ),
            const SizedBox(height: 6),
            Text(
              isLogin  ? 'Sign in to continue your luxury shopping' :
              isSignup ? 'Join the Savaan luxury experience'        :
              isReset  ? 'Enter the code we emailed you and choose a new password' :
                         'We\'ll email a reset code to your email',
              style: const TextStyle(fontSize: 13, color: _textGrey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            if (isSignup) ...[
              _buildInputField(
                controller: _nameController,
                hint: 'Full Name',
                icon: Icons.person_outline,
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Enter your name' : null,
              ),
              const SizedBox(height: 14),
            ],

            if (!isReset)
              _buildInputField(
                controller: _emailController,
                hint: 'Email Address',
                icon: Icons.email_outlined,
                validator: (val) =>
                    val == null || !val.contains('@') ? 'Enter a valid email' : null,
              ),

            if (isReset) ...[
              _buildInputField(
                controller: _otpController,
                hint: '6-Digit Code',
                icon: Icons.pin_outlined,
                validator: (val) =>
                    val == null || val.trim().length != 6 ? 'Enter the 6-digit code' : null,
              ),
              const SizedBox(height: 14),
              _buildPasswordField(
                controller: _newPasswordController,
                hint: 'New Password',
                validator: (val) =>
                    val == null || val.length < 8 ? 'At least 8 characters' : null,
              ),
            ],

            if (isLogin || isSignup) ...[
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
                     isReset   ? 'RESET PASSWORD'  :
                                 'SEND RESET CODE',
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

  Widget _buildPasswordField({
    TextEditingController? controller,
    String hint = 'Password',
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller ?? _passwordController,
      obscureText: _obscurePassword,
      style: const TextStyle(color: _dark, fontSize: 14),
      validator: validator ??
          (val) => val == null || val.length < 6 ? 'Min 6 characters' : null,
      decoration: InputDecoration(
        hintText: hint,
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
    return Image.asset('assets/google logo.png', width: 22, height: 22);
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

