/// ATC vocabulary and phraseology for EU/Belgium aviation
/// Used to enhance transcription accuracy and highlight relevant terms

class AtcVocabulary {
  AtcVocabulary._();

  /// Belgian airports and their ICAO codes
  static const Map<String, String> belgianAirports = {
    'EBBR': 'Brussels Airport',
    'EBAW': 'Antwerp Airport',
    'EBCI': 'Charleroi Airport',
    'EBLG': 'Liege Airport',
    'EBOS': 'Ostend-Bruges Airport',
    'EBKT': 'Kortrijk-Wevelgem',
    'EBSP': 'Spa-La Sauveniere',
    'EBTX': 'Theux-Verviers',
    'EBZH': 'Kiewit',
    'EBGB': 'Grimbergen',
    'EBBT': 'Brasschaat',
    'EBBZ': 'Buzet',
  };

  /// Nearby major airports
  static const Map<String, String> nearbyAirports = {
    'EHAM': 'Amsterdam Schiphol',
    'EDDL': 'Dusseldorf',
    'EDDK': 'Cologne/Bonn',
    'LFPG': 'Paris CDG',
    'ELLX': 'Luxembourg',
    'EHEH': 'Eindhoven',
    'EHRD': 'Rotterdam',
  };

  /// Common ATC instructions
  static const List<String> instructions = [
    'climb',
    'descend',
    'maintain',
    'turn left',
    'turn right',
    'direct to',
    'cleared',
    'contact',
    'squawk',
    'ident',
    'hold position',
    'line up and wait',
    'cleared for takeoff',
    'cleared to land',
    'go around',
    'report',
    'expect',
    'vectors',
    'intercept',
    'established',
    'traffic',
    'caution',
    'wind',
    'runway',
    'approach',
    'departure',
    'heading',
    'altitude',
    'flight level',
    'speed',
    'reduce',
    'increase',
    'expedite',
    'immediately',
    'roger',
    'wilco',
    'affirm',
    'negative',
    'standby',
    'say again',
    'readback correct',
  ];

  /// Belgian FIR frequencies and sectors
  static const Map<String, String> belgianFrequencies = {
    '118.250': 'Brussels Approach',
    '120.775': 'Brussels Departure',
    '126.900': 'Brussels Tower',
    '121.875': 'Brussels Ground',
    '129.100': 'Belgian Radar (North)',
    '126.625': 'Belgian Radar (South)',
    '131.100': 'Eurocontrol Maastricht',
    '132.850': 'Eurocontrol Maastricht',
  };

  /// NATO phonetic alphabet
  static const Map<String, String> phoneticAlphabet = {
    'A': 'Alpha',
    'B': 'Bravo',
    'C': 'Charlie',
    'D': 'Delta',
    'E': 'Echo',
    'F': 'Foxtrot',
    'G': 'Golf',
    'H': 'Hotel',
    'I': 'India',
    'J': 'Juliet',
    'K': 'Kilo',
    'L': 'Lima',
    'M': 'Mike',
    'N': 'November',
    'O': 'Oscar',
    'P': 'Papa',
    'Q': 'Quebec',
    'R': 'Romeo',
    'S': 'Sierra',
    'T': 'Tango',
    'U': 'Uniform',
    'V': 'Victor',
    'W': 'Whiskey',
    'X': 'X-ray',
    'Y': 'Yankee',
    'Z': 'Zulu',
  };

  /// Common Belgian/EU airline callsigns
  static const Map<String, String> airlineCallsigns = {
    'BEL': 'Brussels Airlines (Beeline)',
    'TUI': 'TUI fly Belgium',
    'THY': 'Turkish Airlines',
    'BAW': 'British Airways (Speedbird)',
    'AFR': 'Air France',
    'DLH': 'Lufthansa',
    'KLM': 'KLM',
    'RYR': 'Ryanair',
    'EZY': 'easyJet',
    'VLG': 'Vueling',
    'TAP': 'TAP Portugal',
    'SAS': 'Scandinavian',
    'UAE': 'Emirates',
    'ETD': 'Etihad',
    'QTR': 'Qatar Airways',
  };

  /// Extract potential callsigns from transcribed text
  static List<String> extractCallsigns(String text) {
    final callsigns = <String>[];
    final upperText = text.toUpperCase();

    // Match airline codes followed by numbers
    final airlinePattern = RegExp(r'\b([A-Z]{3})\s*(\d{1,4}[A-Z]?)\b');
    for (final match in airlinePattern.allMatches(upperText)) {
      final code = match.group(1);
      final number = match.group(2);
      if (code != null && number != null) {
        callsigns.add('$code$number');
      }
    }

    // Match general aviation callsigns (e.g., OO-ABC)
    final gaPattern = RegExp(r'\b(OO|OE|PH|D|F|G|LX)-?([A-Z]{3})\b');
    for (final match in gaPattern.allMatches(upperText)) {
      final prefix = match.group(1);
      final suffix = match.group(2);
      if (prefix != null && suffix != null) {
        callsigns.add('$prefix-$suffix');
      }
    }

    return callsigns.toSet().toList();
  }

  /// Check if text contains ATC instruction keywords
  static bool containsAtcInstruction(String text) {
    final lowerText = text.toLowerCase();
    return instructions.any((instruction) => lowerText.contains(instruction));
  }
}
