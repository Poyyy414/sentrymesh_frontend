import 'package:flutter/material.dart';

import '../../app/assets.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/di/injection.dart';
import '../../core/widgets/custom_button.dart';
import '../../data/repositories/auth_repository.dart';
import '../safe_route/state/asean_country.dart';

const _authFieldTextStyle = TextStyle(
  color: AppTheme.textPrimary,
  fontSize: 14,
  fontWeight: FontWeight.w600,
  letterSpacing: 0,
);

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  late AseanCountry _selectedCountry;
  late String _selectedRegion;
  bool _isLoading = false;
  bool _obscurePassword = true;

  static const Map<String, List<String>> _aseanRegions = {
    'BN': ['Brunei-Muara', 'Belait', 'Tutong', 'Temburong'],
    'KH': ['Phnom Penh', 'Battambang', 'Kampong Cham', 'Siem Reap', 'Kandal'],
    'ID': [
      'Jakarta',
      'West Java',
      'Central Java',
      'East Java',
      'Bali',
      'South Sulawesi',
      'Aceh',
    ],
    'LA': [
      'Vientiane Capital',
      'Luang Prabang',
      'Savannakhet',
      'Champasak',
      'Khammouane',
    ],
    'MY': ['Kuala Lumpur', 'Selangor', 'Penang', 'Johor', 'Sabah', 'Sarawak'],
    'MM': [
      'Yangon Region',
      'Mandalay Region',
      'Ayeyarwady Region',
      'Shan State',
      'Rakhine State',
    ],
    'PH': [
      'Bicol Region',
      'National Capital Region',
      'CALABARZON',
      'Central Luzon',
      'Central Visayas',
      'Eastern Visayas',
      'Davao Region',
    ],
    'SG': [
      'Central Region',
      'East Region',
      'North Region',
      'North-East Region',
      'West Region',
    ],
    'TH': [
      'Bangkok',
      'Chiang Mai',
      'Nakhon Ratchasima',
      'Phuket',
      'Songkhla',
      'Ubon Ratchathani',
    ],
    'TL': ['Dili', 'Baucau', 'Bobonaro', 'Ermera', 'Liquica', 'Manatuto'],
    'VN': [
      'Ha Noi',
      'Ho Chi Minh City',
      'Da Nang',
      'Mekong Delta',
      'Central Coast',
      'Red River Delta',
    ],
  };

  @override
  void initState() {
    super.initState();
    _selectedCountry = AseanCountry.defaultCountry;
    _selectedRegion = _regionsFor(_selectedCountry).first;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isLoading) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AppDependenciesScope.of(context).authRepository.register(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        email: _emailController.text,
        address: _formattedAddress,
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRouter.appShell, (_) => false);
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Unable to create account right now.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _required(String? value, String label) {
    if ((value ?? '').trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  List<String> _regionsFor(AseanCountry country) {
    return _aseanRegions[country.code] ?? const ['General area'];
  }

  String get _formattedAddress {
    final streetAddress = _addressController.text.trim();
    return '$streetAddress, $_selectedRegion, ${_selectedCountry.name}';
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) {
      return 'Password is required';
    }
    if (text.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.deepNavy,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppTheme.signalBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(AppAssets.appIcon, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Resident profile',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Create your SentryMesh account.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firstNameController,
                          style: _authFieldTextStyle,
                          textInputAction: TextInputAction.next,
                          validator: (value) => _required(value, 'First name'),
                          decoration: const InputDecoration(
                            labelText: 'First name',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _lastNameController,
                          style: _authFieldTextStyle,
                          textInputAction: TextInputAction.next,
                          validator: (value) => _required(value, 'Last name'),
                          decoration: const InputDecoration(
                            labelText: 'Last name',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    style: _authFieldTextStyle,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: _validateEmail,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<AseanCountry>(
                    initialValue: _selectedCountry,
                    isExpanded: true,
                    style: _authFieldTextStyle,
                    dropdownColor: AppTheme.surfaceRaised,
                    items: AseanCountry.countries.map((country) {
                      return DropdownMenuItem(
                        value: country,
                        child: Text(country.name),
                      );
                    }).toList(),
                    onChanged: _isLoading
                        ? null
                        : (country) {
                            if (country == null) {
                              return;
                            }

                            setState(() {
                              _selectedCountry = country;
                              _selectedRegion = _regionsFor(country).first;
                            });
                          },
                    decoration: const InputDecoration(
                      labelText: 'Country',
                      prefixIcon: Icon(Icons.public),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_selectedCountry.code),
                    initialValue: _selectedRegion,
                    isExpanded: true,
                    style: _authFieldTextStyle,
                    dropdownColor: AppTheme.surfaceRaised,
                    items: _regionsFor(_selectedCountry).map((region) {
                      return DropdownMenuItem(
                        value: region,
                        child: Text(region),
                      );
                    }).toList(),
                    onChanged: _isLoading
                        ? null
                        : (region) {
                            if (region == null) {
                              return;
                            }

                            setState(() {
                              _selectedRegion = region;
                            });
                          },
                    decoration: const InputDecoration(
                      labelText: 'Region / location',
                      prefixIcon: Icon(Icons.map_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    style: _authFieldTextStyle,
                    textInputAction: TextInputAction.next,
                    validator: (value) =>
                        _required(value, 'Barangay or address'),
                    decoration: const InputDecoration(
                      labelText: 'Barangay / street address',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    style: _authFieldTextStyle,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    validator: _validatePassword,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SentryButton(
                    label: 'Create Account',
                    icon: Icons.person_add,
                    isLoading: _isLoading,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Sign In'),
            ),
          ],
        ),
      ),
    );
  }
}
