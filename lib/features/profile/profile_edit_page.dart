import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/localization/app_localizations.dart';
import '../../shared/app_state.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  DateTime? _birthDate;
  String? _avatarPath;

  @override
  void initState() {
    super.initState();
    final state = ref.read(appStateProvider);
    _firstNameController = TextEditingController(text: state.firstName);
    _lastNameController = TextEditingController(text: state.lastName);
    _birthDate = state.birthDate;
    _avatarPath = state.avatarPath;
    WidgetsBinding.instance.addPostFrameCallback((_) => _retrieveLostData());
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: Text(strings.profileEditTitle)),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              32 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            children: [
              Center(
                child: _EditableAvatar(
                  firstName: _firstNameController.text,
                  lastName: _lastNameController.text,
                  avatarPath: _avatarPath,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pickAvatar(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(strings.profileAvatarGallery),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickAvatar(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(strings.profileAvatarCamera),
                  ),
                ],
              ),
              if (_avatarPath != null) ...[
                const SizedBox(height: 4),
                Center(
                  child: TextButton.icon(
                    onPressed: () => setState(() => _avatarPath = null),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(strings.profileAvatarRemove),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                strings.profileAvatarDemoNotice,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _firstNameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.givenName],
                decoration: InputDecoration(
                  labelText: strings.profileFirstNameLabel,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? strings.profileFirstNameRequired
                    : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _lastNameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.familyName],
                decoration: InputDecoration(
                  labelText: strings.profileLastNameLabel,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? strings.profileLastNameRequired
                    : null,
                onChanged: (_) => setState(() {}),
                onFieldSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 14),
              Semantics(
                button: true,
                label: strings.profileBirthDateLabel,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _selectBirthDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: strings.profileBirthDateLabel,
                      suffixIcon: _birthDate == null
                          ? const Icon(Icons.calendar_today_outlined)
                          : IconButton(
                              onPressed: () =>
                                  setState(() => _birthDate = null),
                              tooltip: strings.profileBirthDateClear,
                              icon: const Icon(Icons.close),
                            ),
                    ),
                    child: Text(
                      _birthDate == null
                          ? strings.profileBirthDateOptional
                          : strings.profileBirthDateValue(_birthDate!),
                      style: _birthDate == null
                          ? theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            )
                          : theme.textTheme.bodyLarge,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: Text(strings.profileSave),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectBirthDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (selected != null && mounted) {
      setState(() => _birthDate = selected);
    }
  }

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (image != null && mounted) {
        setState(() => _avatarPath = image.path);
      }
    } on PlatformException {
      _showPickerError();
    } catch (_) {
      _showPickerError();
    }
  }

  Future<void> _retrieveLostData() async {
    try {
      final response = await _picker.retrieveLostData();
      if (!mounted || response.isEmpty) return;
      final files = response.files;
      if (files != null && files.isNotEmpty) {
        setState(() => _avatarPath = files.first.path);
      } else if (response.exception != null) {
        _showPickerError();
      }
    } on PlatformException {
      _showPickerError();
    } catch (_) {
      _showPickerError();
    }
  }

  void _showPickerError() {
    if (!mounted) return;
    final strings = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(strings.profileAvatarPickerError)),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final strings = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    ref
        .read(appStateProvider.notifier)
        .updateProfile(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          birthDate: _birthDate,
          avatarPath: _avatarPath,
          clearBirthDate: _birthDate == null,
          clearAvatarPath: _avatarPath == null,
        );
    context.pop();
    messenger.showSnackBar(SnackBar(content: Text(strings.profileSaved)));
  }
}

class _EditableAvatar extends StatelessWidget {
  const _EditableAvatar({
    required this.firstName,
    required this.lastName,
    required this.avatarPath,
  });

  final String firstName;
  final String lastName;
  final String? avatarPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final path = avatarPath?.trim();
    final initials = _initials(firstName, lastName);
    final fallback = initials.isEmpty
        ? const Icon(Icons.person_outline, size: 48)
        : Text(
            initials,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          );
    return Semantics(
      image: true,
      label: AppLocalizations.of(context).profileAvatarLabel,
      child: CircleAvatar(
        radius: 54,
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        child: path == null || path.isEmpty
            ? fallback
            : ClipOval(
                child: Image.file(
                  File(path),
                  width: 108,
                  height: 108,
                  fit: BoxFit.cover,
                  cacheWidth: 384,
                  filterQuality: FilterQuality.low,
                  errorBuilder: (context, error, stackTrace) => SizedBox(
                    width: 108,
                    height: 108,
                    child: Center(child: fallback),
                  ),
                ),
              ),
      ),
    );
  }
}

String _initials(String firstName, String lastName) {
  final parts = [
    firstName.trim(),
    lastName.trim(),
  ].where((part) => part.isNotEmpty).take(2);
  return parts.map((part) => part.substring(0, 1).toUpperCase()).join();
}
