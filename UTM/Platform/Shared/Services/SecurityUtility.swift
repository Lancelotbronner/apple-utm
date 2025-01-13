////
//// Copyright © 2025 osy. All rights reserved.
////
//// Licensed under the Apache License, Version 2.0 (the "License");
//// you may not use this file except in compliance with the License.
//// You may obtain a copy of the License at
////
////     http://www.apache.org/licenses/LICENSE-2.0
////
//// Unless required by applicable law or agreed to in writing, software
//// distributed under the License is distributed on an "AS IS" BASIS,
//// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//// See the License for the specific language governing permissions and
//// limitations under the License.
////
//
//import Foundation
//import Security
//import CryptoKit
//
//struct SecurityUtility {
//
//    static func generate(
//        commonName: String,
//        organizationName: String,
//        serial: Int,
//        days: Int,
//        isClient: Bool
//    ) throws -> (p12: Date, privatePEM: Data, publicPEM: Data, publicKey: Data) {
//
//        let attributes: [String: Any] = [
//            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
//            kSecAttrKeySizeInBits as String: 4096,
//            kSecPrivateKeyAttrs as String: [
//                kSecAttrIsPermanent as String: true,
//                kSecAttrApplicationTag as String: organizationName.data(using: .utf8)!,
//                kSecAttrLabel as String: commonName,
//            ]
//        ]
//
//        var privateKey: SecKey?
//        var publicKey: SecKey?
//
//        let status = SecKeyGeneratePair(attributes as CFDictionary, &publicKey, &privateKey)
//        guard status == errSecSuccess, let privateKey, let publicKey else {
//            let message = SecCopyErrorMessageString(status, nil) as? String ?? "unknown error"
//            fatalError("Error generating RSA key pair: \(message)")
//        }
//
////        kSecOIDX509V1ValidityNotBefore as String: 0,
////        kSecOIDX509V1ValidityNotAfter as String: 60*60*24*days,
////        kSecAttrSerialNumber as String: serial
//
////        let certificate
//
//        /*
//         X509_set_version(x, 2);
//         ASN1_INTEGER_set(X509_get_serialNumber(x), serial);
//         X509_gmtime_adj(X509_get_notBefore(x), 0);
//         X509_gmtime_adj(X509_get_notAfter(x), (long)60*60*24*days);
//         X509_set_pubkey(x, pk);
//
//         name = X509_get_subject_name(x);
//
//         /* This function creates and adds the entry, working out the
//          * correct string type and performing checks on its length.
//          * Normally we'd check the return value for errors...
//          */
//         X509_NAME_add_entry_by_txt(name, SN_commonName,
//                     MBSTRING_UTF8, (const unsigned char *)commonName, -1, -1, 0);
//         X509_NAME_add_entry_by_txt(name, SN_organizationName,
//                     MBSTRING_UTF8, (const unsigned char *)organizationName, -1, -1, 0);
//
//         /* Its self signed so set the issuer name to be the same as the
//           * subject.
//          */
//         X509_set_issuer_name(x, name);
//
//         /* Add various extensions: standard extensions */
//         add_ext(x, NID_basic_constraints, "critical,CA:TRUE");
//         add_ext(x, NID_key_usage, "critical,keyCertSign,cRLSign,keyEncipherment,digitalSignature");
//         if (isClient) {
//             add_ext(x, NID_ext_key_usage, "clientAuth");
//         } else {
//             add_ext(x, NID_ext_key_usage, "serverAuth");
//         }
//         add_ext(x, NID_subject_key_identifier, "hash");
//         */
//
//        var privatePEM: CFData?
//        let status = SecItemExport(privateKey, .kSecFormatPKCS12, .kSecItemPemArmour, nil, &privatePEM)
//        guard status == errSecSuccess, let privatePEM = privatePEM as? Data else {
//            let message = SecCopyErrorMessageString(status, nil) as? String ?? "unknown error"
//            fatalError("Error generating private PEM: \(message)")
//        }
//
//        var publicPEM: CFData?
//        let status = SecItemExport(publicKey, SecExternalFormat.kSecFormatPKCS12, .kSecItemPemArmour, nil, &publicPEM)
//        guard status == errSecSuccess, let publicPEM = publicPEM as? Data else {
//            let message = SecCopyErrorMessageString(status, nil) as? String ?? "unknown error"
//            fatalError("Error generating private PEM: \(message)")
//        }
//
//        arr[0] = CreateP12FromKey(pkey, cert);
//        arr[1] = CreatePrivatePEMFromKey(pkey);
//        arr[2] = CreatePublicPEMFromCert(cert);
//        arr[3] = CreatePublicKeyFromCert(cert);
//        if (arr[0] && arr[1] && arr[2] && arr[3]) {
//            cfarr = CFArrayCreate(kCFAllocatorDefault, (const void **)arr, 4, &kCFTypeArrayCallBacks);
//        }
//        if (arr[0]) {
//            CFRelease(arr[0]);
//        }
//        if (arr[1]) {
//            CFRelease(arr[1]);
//        }
//        if (arr[2]) {
//            CFRelease(arr[2]);
//        }
//        if (arr[3]) {
//            CFRelease(arr[3]);
//        }
//        EVP_PKEY_free(pkey);
//        X509_free(cert);
//        return cfarr;
//    }
//
//}
