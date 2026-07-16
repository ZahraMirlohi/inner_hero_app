// lib/features/profile/models/hero_class_model.dart

class HeroClass {
  final String id;
  final String name;
  final String icon;
  final String description;
  final List<String> outfits;
  final List<String> animations;
  final String defaultOutfit;
  final String defaultAccessory;
  final String bgColor;
  final String primaryColor;

  HeroClass({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.outfits,
    required this.animations,
    required this.defaultOutfit,
    required this.defaultAccessory,
    required this.bgColor,
    required this.primaryColor,
  });

  static List<HeroClass> get allClasses => [
    HeroClass(
      id: 'warrior',
      name: 'جنگجو',
      icon: '⚔️',
      description: 'جنگجویان شجاع و قدرتمند هستند. آنها هرگز تسلیم نمی‌شوند.',
      outfits: ['armor_blue', 'armor_red', 'armor_gold', 'armor_dark'],
      animations: ['idle', 'attack', 'victory', 'dance'],
      defaultOutfit: 'armor_blue',
      defaultAccessory: 'sword',
      bgColor: '#1A1A2E',
      primaryColor: '#4A90E2',
    ),
    HeroClass(
      id: 'doctor',
      name: 'دکتر',
      icon: '👨‍⚕️',
      description: 'دکترها با علم و دانش خود به درمان دیگران کمک می‌کنند.',
      outfits: ['lab_coat', 'scrubs_blue', 'scrubs_green', 'white_coat'],
      animations: ['idle', 'heal', 'research', 'dance'],
      defaultOutfit: 'lab_coat',
      defaultAccessory: 'stethoscope',
      bgColor: '#1A2E1A',
      primaryColor: '#2ECC71',
    ),
    HeroClass(
      id: 'athlete',
      name: 'ورزشکار',
      icon: '🏃‍♂️',
      description: 'ورزشکاران با قدرت و استقامت خود الهام‌بخش دیگران هستند.',
      outfits: ['sport_blue', 'sport_red', 'sport_black', 'sport_white'],
      animations: ['idle', 'run', 'victory', 'dance', 'stretch'],
      defaultOutfit: 'sport_blue',
      defaultAccessory: 'medal',
      bgColor: '#1A1A2E',
      primaryColor: '#F39C12',
    ),
    HeroClass(
      id: 'scientist',
      name: 'دانشمند',
      icon: '🧪',
      description: 'دانشمندان با کنجکاوی و تحقیق خود دنیا را کشف می‌کنند.',
      outfits: ['lab_white', 'lab_blue', 'lab_green', 'professor'],
      animations: ['idle', 'research', 'experiment', 'dance'],
      defaultOutfit: 'lab_white',
      defaultAccessory: 'glasses',
      bgColor: '#1A1A2E',
      primaryColor: '#9B59B6',
    ),
    HeroClass(
      id: 'general',
      name: 'ژنرال',
      icon: '🎖️',
      description: 'ژنرال‌ها رهبران قدرتمندی هستند که دیگران را هدایت می‌کنند.',
      outfits: ['uniform_blue', 'uniform_red', 'uniform_gold', 'uniform_dark'],
      animations: ['idle', 'command', 'victory', 'dance'],
      defaultOutfit: 'uniform_blue',
      defaultAccessory: 'medal_gold',
      bgColor: '#1A1A2E',
      primaryColor: '#E74C3C',
    ),
    HeroClass(
      id: 'mage',
      name: 'جادوگر',
      icon: '🧙‍♂️',
      description: 'جادوگران با قدرت های جادویی خود دنیا را متحول می‌کنند.',
      outfits: ['robe_purple', 'robe_blue', 'robe_red', 'robe_dark'],
      animations: ['idle', 'cast', 'victory', 'dance', 'fly'],
      defaultOutfit: 'robe_purple',
      defaultAccessory: 'staff',
      bgColor: '#1A0A2E',
      primaryColor: '#9B59B6',
    ),
  ];

  static HeroClass getClass(String id) {
    return allClasses.firstWhere(
      (c) => c.id == id,
      orElse: () => allClasses[0],
    );
  }
}
