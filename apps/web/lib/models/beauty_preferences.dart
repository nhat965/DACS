class BeautyPreferences {
  const BeautyPreferences({
    this.skinType,
    this.skinConcerns = const [],
    this.careGoals = const [],
    this.preferredCategories = const [],
    this.preferredBrands = const [],
    this.avoidIngredients = const [],
    this.budgetMin,
    this.budgetMax,
    this.currency = 'USD',
    this.completed = false,
  });

  final String? skinType;
  final List<String> skinConcerns;
  final List<String> careGoals;
  final List<String> preferredCategories;
  final List<String> preferredBrands;
  final List<String> avoidIngredients;
  final double? budgetMin;
  final double? budgetMax;
  final String currency;
  final bool completed;

  factory BeautyPreferences.fromJson(Map<String, dynamic> json) {
    List<String> values(String key) => (json[key] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList();
    return BeautyPreferences(
      skinType: json['skinType']?.toString(),
      skinConcerns: values('skinConcerns'),
      careGoals: values('careGoals'),
      preferredCategories: values('preferredCategories'),
      preferredBrands: values('preferredBrands'),
      avoidIngredients: values('avoidIngredients'),
      budgetMin: (json['budgetMin'] as num?)?.toDouble(),
      budgetMax: (json['budgetMax'] as num?)?.toDouble(),
      currency: json['currency']?.toString() ?? 'USD',
      completed: json['completed'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'skinType': skinType,
    'skinConcerns': skinConcerns,
    'careGoals': careGoals,
    'preferredCategories': preferredCategories,
    'preferredBrands': preferredBrands,
    'avoidIngredients': avoidIngredients,
    'budgetMin': budgetMin,
    'budgetMax': budgetMax,
    'currency': currency,
    'budgetCurrency': currency,
  };

  Map<String, dynamic> toRecommendationContext() => {
    'skinType': skinType,
    'skinConcerns': skinConcerns,
    'careGoals': careGoals,
    'preferredCategories': preferredCategories,
    'preferredBrands': preferredBrands,
    'avoidIngredients': avoidIngredients,
    'budgetMin': budgetMin,
    'budgetMax': budgetMax,
    'budgetCurrency': currency,
  };
}
