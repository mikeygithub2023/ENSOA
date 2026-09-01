import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Démo uniquement : mots de passe/PIN jamais stockés en clair, même côté mock.
/// Un vrai backend ferait ce hachage (argon2/bcrypt) côté serveur.
String hashPin(String pin, String salt) {
  final bytes = utf8.encode('$salt::$pin');
  return sha256.convert(bytes).toString();
}

class MockCredential {
  final String matricule;
  final String userId;
  final String salt;
  final String pinHash;

  const MockCredential({
    required this.matricule,
    required this.userId,
    required this.salt,
    required this.pinHash,
  });
}

final List<MockCredential> mockCredentials = [
  // Cdt Diabaté N. — Chef Soutien Technique
  MockCredential(
    matricule: 'ENSOA-0001',
    userId: 'u1',
    salt: 'slt1',
    pinHash: hashPin('1234', 'slt1'),
  ),
  // Adj Bamba S. — Soutien pétrolier
  MockCredential(
    matricule: 'ENSOA-0298',
    userId: 'u2',
    salt: 'slt2',
    pinHash: hashPin('2345', 'slt2'),
  ),
  // Cpl Yao R. — Garage
  MockCredential(
    matricule: 'ENSOA-0410',
    userId: 'u3',
    salt: 'slt3',
    pinHash: hashPin('3456', 'slt3'),
  ),
  // Sgt Traoré M. — Armurerie
  MockCredential(
    matricule: 'ENSOA-0355',
    userId: 'u4',
    salt: 'slt4',
    pinHash: hashPin('4567', 'slt4'),
  ),
];
