double asDouble(dynamic value, {double fallback = 0}) {
	if (value is num) {
		return value.toDouble();
	}

	return double.tryParse(value?.toString() ?? '') ?? fallback;
}

int asInt(dynamic value, {int fallback = 0}) {
	if (value is num) {
		return value.toInt();
	}

	return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String formatOneDecimal(double value) => value.toStringAsFixed(1);

String formatZeroOrOneDecimal(double value) {
	if (value % 1 == 0) {
		return value.toStringAsFixed(0);
	}

	return value.toStringAsFixed(1);
}
