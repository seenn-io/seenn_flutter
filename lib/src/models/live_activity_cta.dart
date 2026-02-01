/// CTA Button style presets
enum LiveActivityCTAButtonStyle {
  primary,
  secondary,
  outline,
}

/// CTA button configuration for Live Activity completion
class LiveActivityCTAButton {
  /// Button text
  final String text;

  /// Deep link URL to open when tapped
  final String deepLink;

  /// Button style preset
  final LiveActivityCTAButtonStyle? style;

  /// Custom background color (hex)
  final String? backgroundColor;

  /// Custom text color (hex)
  final String? textColor;

  /// Corner radius (default: 20)
  final int? cornerRadius;

  const LiveActivityCTAButton({
    required this.text,
    required this.deepLink,
    this.style,
    this.backgroundColor,
    this.textColor,
    this.cornerRadius,
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'deepLink': deepLink,
      if (style != null) 'style': style!.name,
      if (backgroundColor != null) 'backgroundColor': backgroundColor,
      if (textColor != null) 'textColor': textColor,
      if (cornerRadius != null) 'cornerRadius': cornerRadius,
    };
  }

  factory LiveActivityCTAButton.fromMap(Map<String, dynamic> map) {
    return LiveActivityCTAButton(
      text: map['text'] as String,
      deepLink: map['deepLink'] as String,
      style: map['style'] != null
          ? LiveActivityCTAButtonStyle.values.firstWhere(
              (e) => e.name == map['style'],
              orElse: () => LiveActivityCTAButtonStyle.primary,
            )
          : null,
      backgroundColor: map['backgroundColor'] as String?,
      textColor: map['textColor'] as String?,
      cornerRadius: map['cornerRadius'] as int?,
    );
  }
}
