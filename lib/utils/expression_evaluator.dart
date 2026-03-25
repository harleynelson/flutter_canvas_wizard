// File: lib/utils/expression_evaluator.dart
// Description: Evaluates logical string expressions against variables. Now supports AND (&&) and OR (||).

class ExpressionEvaluator {
  static bool evaluate(String? expression, Map<String, double> variables) {
    if (expression == null || expression.trim().isEmpty) return true;
    
    try {
      final exp = expression.trim();
      
      // Handle hardcoded booleans
      if (exp.toLowerCase() == 'true') return true;
      if (exp.toLowerCase() == 'false') return false;

      // Evaluate OR conditions first (lowest precedence)
      if (exp.contains('||')) {
        final parts = exp.split('||');
        for (var part in parts) {
          if (evaluate(part, variables)) return true;
        }
        return false;
      }

      // Evaluate AND conditions
      if (exp.contains('&&')) {
        final parts = exp.split('&&');
        for (var part in parts) {
          if (!evaluate(part, variables)) return false;
        }
        return true;
      }

      // Find the operator for a simple expression
      final operators = ['>=', '<=', '==', '!=', '>', '<'];
      String? activeOperator;
      for (var op in operators) {
        if (exp.contains(op)) {
          activeOperator = op;
          break;
        }
      }

      // If no operator found, assume it's checking for existence/truthiness (> 0)
      if (activeOperator == null) {
        final val = _getValue(exp, variables);
        return val != null && val > 0;
      }

      // Split the expression into left and right sides
      final parts = exp.split(activeOperator);
      if (parts.length != 2) return false;

      final leftVal = _getValue(parts[0].trim(), variables) ?? 0.0;
      final rightVal = _getValue(parts[1].trim(), variables) ?? 0.0;

      switch (activeOperator) {
        case '>=': return leftVal >= rightVal;
        case '<=': return leftVal <= rightVal;
        case '==': return leftVal == rightVal;
        case '!=': return leftVal != rightVal;
        case '>': return leftVal > rightVal;
        case '<': return leftVal < rightVal;
        default: return false;
      }
    } catch (e) {
      print('DEBUG ERROR: Expression evaluation failed for "$expression": $e');
      return true; // Default to visible on error so items don't vanish randomly
    }
  }

  static double? _getValue(String token, Map<String, double> variables) {
    try {
      final numValue = double.tryParse(token);
      if (numValue != null) return numValue;
      return variables[token];
    } catch (e) {
      print('DEBUG ERROR: Failed to parse token "$token": $e');
      return null;
    }
  }
}