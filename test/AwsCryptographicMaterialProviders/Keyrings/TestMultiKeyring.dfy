// Copyright Amazon.com Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

include "../../../src/AwsCryptographicMaterialProviders/Keyrings/MultiKeyring.dfy"
include "../../../src/AwsCryptographicMaterialProviders/Keyrings/RawAESKeyring.dfy"
include "../../../src/AwsCryptographicMaterialProviders/AlgorithmSuites.dfy"
include "../../../src/AwsCryptographicMaterialProviders/Materials.dfy"
include "../../../src/Crypto/AESEncryption.dfy"
include "../../../src/StandardLibrary/StandardLibrary.dfy"
include "../../../src/Generated/AwsCryptographicMaterialProviders.dfy"
include "../../Util/TestUtils.dfy"

module TestMultiKeyring {
  import opened Wrappers
  import opened UInt = StandardLibrary.UInt
  import AESEncryption
  import MaterialProviders.MultiKeyring
  import MaterialProviders.RawAESKeyring
  import MaterialProviders.Materials
  import Aws.Crypto
  import opened TestUtils

  method getInputEncryptionMaterials(encryptionContext: Crypto.EncryptionContext) returns (res: Crypto.EncryptionMaterials) {
    return Crypto.EncryptionMaterials(
      encryptionContext:=encryptionContext,
      algorithmSuiteId := Crypto.ALG_AES_256_GCM_IV12_TAG16_HKDF_SHA256,
      signingKey := None(),
      plaintextDataKey:=None(),
      encryptedDataKeys:=[]
    );
  }

  method getInputDecryptionMaterials(encryptionContext: Crypto.EncryptionContext) returns (res: Crypto.DecryptionMaterials) {
    return Crypto.DecryptionMaterials(
      encryptionContext:=encryptionContext,
      algorithmSuiteId := Crypto.ALG_AES_256_GCM_IV12_TAG16_HKDF_SHA256,
      verificationKey := None(),
      plaintextDataKey:=None()
    );
  }

  method {:test} TestHappyCase()
  {
    var encryptionContext := TestUtils.SmallEncryptionContext(TestUtils.SmallEncryptionContextVariation.A);
    var encryptionMaterials := getInputEncryptionMaterials(encryptionContext);
    var decryptionMaterials := getInputDecryptionMaterials(encryptionContext);

    // To confirm that the multi-keyring is generating the plaintext data key using the generator, we'll
    // directly get materials using the generator
    var rawAESKeyring := setupRawAesKeyring(encryptionContext);
    var expectedEncryptionMaterials := rawAESKeyring.OnEncrypt(
      Crypto.OnEncryptInput(materials:=encryptionMaterials)
    );
    expect expectedEncryptionMaterials.Success?;
    var expectedPlaintextDataKey := expectedEncryptionMaterials.value.materials.plaintextDataKey;
    expect expectedPlaintextDataKey.Some?;

    var staticKeyring := new StaticKeyring(Some(expectedEncryptionMaterials.value.materials), None());

    var multiKeyring := new MultiKeyring.MultiKeyring(
        generatorKeyring := Some(staticKeyring),
        childKeyrings := [rawAESKeyring]
    );

    var result := multiKeyring.OnEncrypt(Crypto.OnEncryptInput(materials:=encryptionMaterials));
    expect result.Success?;

    //= compliance/framework/multi-keyring.txt#2.7.1
    //= type=test
    //# If this keyring has a generator keyring, this keyring MUST first
    //# generate a plaintext data key using the generator keyring:

    //= compliance/framework/multi-keyring.txt#2.7.1
    //= type=test
    //# *  This keyring MUST first call the generator keyring's OnEncrypt
    //# using the input encryption materials as input.
    expect result.value.materials.plaintextDataKey.value == expectedPlaintextDataKey.value;

    //= compliance/framework/multi-keyring.txt#2.7.1
    //= type=test
    //# Next, for each keyring (keyring-interface.md) in this keyring's list
    //# of child keyrings (Section 2.6.2), the keyring MUST call OnEncrypt
    //# (keyring-interface.md#onencrypt).

    //= compliance/framework/multi-keyring.txt#2.7.1
    //= type=test
    //# If all previous OnEncrypt (keyring-interface.md#onencrypt) calls
    //# succeeded, this keyring MUST return the encryption materials
    //# (structures.md#encryption-materials) returned by the last OnEncrypt
    //# call.
    expect |result.value.materials.encryptedDataKeys| == 2;
  }

  method {:test} TestChildKeyringFailureEncrypt() {
    //= compliance/framework/multi-keyring.txt#2.7.1
    //= type=test
    //# If the child keyring's OnEncrypt (keyring-
    //# interface.md#onencrypt) fails, this OnEncrypt MUST also fail.
    var encryptionContext := TestUtils.SmallEncryptionContext(TestUtils.SmallEncryptionContextVariation.A);
    var rawAESKeyring := setupRawAesKeyring(encryptionContext);
    var failingKeyring := new FailingKeyring();

    var multiKeyring := new MultiKeyring.MultiKeyring(
        generatorKeyring := Some(rawAESKeyring),
        childKeyrings := [failingKeyring]
    );

    var encryptionMaterials := getInputEncryptionMaterials(encryptionContext);

    var result := multiKeyring.OnEncrypt(Crypto.OnEncryptInput(materials:=encryptionMaterials));
    expect result.IsFailure();
  }

  method {:test} TestGeneratorKeyringFails() {
    //= compliance/framework/multi-keyring.txt#2.7.1
    //= type=test
    //# *  If the generator keyring fails OnEncrypt, this OnEncrypt MUST also
    //# fail.
    var encryptionContext := TestUtils.SmallEncryptionContext(TestUtils.SmallEncryptionContextVariation.A);
    var failingKeyring := new FailingKeyring();

    // We'll add a functional AES keyring as a small validation that something *could* have succeeded in
    // generating but the call still fails.
    var rawAESKeyring := setupRawAesKeyring(encryptionContext);

    var multiKeyring := new MultiKeyring.MultiKeyring(
        generatorKeyring := Some(failingKeyring),
        childKeyrings := [rawAESKeyring]
    );

    var encryptionMaterials := getInputEncryptionMaterials(encryptionContext);

    var result := multiKeyring.OnEncrypt(Crypto.OnEncryptInput(materials:=encryptionMaterials));
    expect result.IsFailure();
  }

  method {:test} TestGeneratorKeyringDoesNotReturnPlaintextDataKey() {
    //= compliance/framework/multi-keyring.txt#2.7.1
    //= type=test
    //# *  If the generator keyring returns encryption materials missing a
    //# plaintext data key, OnEncrypt MUST fail.
    var encryptionContext := TestUtils.SmallEncryptionContext(TestUtils.SmallEncryptionContextVariation.A);
    var encryptionMaterials := getInputEncryptionMaterials(encryptionContext);
    var failingKeyring := new StaticKeyring(Some(encryptionMaterials), None());

    var multiKeyring := new MultiKeyring.MultiKeyring(
        generatorKeyring := Some(failingKeyring),
        childKeyrings := []
    );

    var result := multiKeyring.OnEncrypt(Crypto.OnEncryptInput(materials:=encryptionMaterials));
    expect result.IsFailure();
  }

  method {:test} TestGeneratorAbleToDecrypt() {
    //= compliance/framework/multi-keyring.txt#2.7.2
    //= type=test
    //# Otherwise, OnDecrypt MUST first attempt to decrypt the encrypted data
    //# keys (structures.md#encrypted-data-keys-1) in the input decryption
    //# materials (structures.md#decryption-materials) using its generator
    //# keyring (Section 2.6.1).

    // Generate some materials to decrypt
    var encryptionContext := TestUtils.SmallEncryptionContext(TestUtils.SmallEncryptionContextVariation.A);
    var rawAESKeyring := setupRawAesKeyring(encryptionContext);
    var inputEncryptionMaterials := getInputEncryptionMaterials(encryptionContext);
    var encryptionMaterials := rawAESKeyring.OnEncrypt(Crypto.OnEncryptInput(materials:=inputEncryptionMaterials));
    expect encryptionMaterials.Success?;

    var inputDecryptionMaterials := getInputDecryptionMaterials(encryptionContext);

    var failingKeyring := new FailingKeyring();

    var multiKeyring := new MultiKeyring.MultiKeyring(
        generatorKeyring := Some(rawAESKeyring),
        childKeyrings := [failingKeyring]
    );

    var onDecryptInput := Crypto.OnDecryptInput(
      materials := inputDecryptionMaterials, encryptedDataKeys := encryptionMaterials.value.materials.encryptedDataKeys
    );

    var decryptionMaterials := multiKeyring.OnDecrypt(input:=onDecryptInput);
    expect decryptionMaterials.Success?;
    expect decryptionMaterials.value.materials.plaintextDataKey == encryptionMaterials.value.materials.plaintextDataKey;
  }

  method {:test} TestGeneratorUnableToDecrypt() {
    //= compliance/framework/multi-keyring.txt#2.7.2
    //= type=test
    //# If the generator keyring is unable to
    //# decrypt the materials, the multi-keyring MUST attempt to decrypt
    //# using its child keyrings, until one either succeeds in decryption or
    //# all have failed.

    //= compliance/framework/multi-keyring.txt#2.7.2
    //= type=TODO
    //# For each keyring (keyring-interface.md) to be used for decryption,
    //# the multi-keyring MUST call that keyring's OnDecrypt (keyring-
    //# interface.md#ondecrypt) using the unmodified decryption materials
    //# (structures.md#decryption-materials) and the input encrypted data key
    //# (structures.md#encrypted-data-key) list.
    // Marked as TODO because we don't yet have a way of confirming the exact
    // parameters passed to child keyrings. Investigate our "spy" patterns at
    // some point

    // Generate some materials to decrypt
    var encryptionContext := TestUtils.SmallEncryptionContext(TestUtils.SmallEncryptionContextVariation.A);
    var rawAESKeyring := setupRawAesKeyring(encryptionContext);
    var inputEncryptionMaterials := getInputEncryptionMaterials(encryptionContext);
    var encryptionMaterials := rawAESKeyring.OnEncrypt(Crypto.OnEncryptInput(materials:=inputEncryptionMaterials));
    expect encryptionMaterials.Success?;

    var inputDecryptionMaterials := getInputDecryptionMaterials(encryptionContext);

    var failingKeyring := new FailingKeyring();

    // For children, we add failing keyrings on both sides of the valid keyring so we exercise
    // all paths
    var multiKeyring := new MultiKeyring.MultiKeyring(
        generatorKeyring := Some(failingKeyring),
        childKeyrings := [failingKeyring, rawAESKeyring, failingKeyring]
    );

    var onDecryptInput := Crypto.OnDecryptInput(
      materials := inputDecryptionMaterials, encryptedDataKeys := encryptionMaterials.value.materials.encryptedDataKeys
    );

    //= compliance/framework/multi-keyring.txt#2.7.2
    //= type=TODO
    //# If OnDecrypt (keyring-
    //# interface.md#ondecrypt) returns decryption materials
    //# (structures.md#decryption-materials) containing a plaintext data key,
    //# the multi-keyring MUST immediately return the modified decryption
    //# materials.
    // Marked as TODO because we don't yet have a way of confirming the "immediately"
    // requirement. We ensure we got the right output, but we don't ensure we didn't try
    // the other keyrings before returning. Look into the "spy" pattern at some point
    var decryptionMaterials := multiKeyring.OnDecrypt(input:=onDecryptInput);
    expect decryptionMaterials.Success?;
    expect decryptionMaterials.value.materials.plaintextDataKey == encryptionMaterials.value.materials.plaintextDataKey;
  }

  method {:test} TestCollectFailuresDecrypt()
  {
    //= compliance/framework/multi-keyring.txt#2.7.2
    //= type=test
    //# If the child keyring's OnDecrypt call fails, the multi-
    //# keyring MUST collect the error and continue to the next keyring, if
    //# any.

    //= compliance/framework/multi-keyring.txt#2.7.2
    //= type=test
    //# If, after calling OnDecrypt (keyring-interface.md#ondecrypt) on every
    //# child keyring (Section 2.6.2) (and possibly the generator keyring
    //# (Section 2.6.1)), the decryption materials (structures.md#decryption-
    //# materials) still do not contain a plaintext data key, OnDecrypt MUST
    //# return a failure message containing the collected failure messages
    //# from the child keyrings.
    var encryptionContext := TestUtils.SmallEncryptionContext(TestUtils.SmallEncryptionContextVariation.A);

    var failingKeyring := new FailingKeyring();
    var multiKeyring := new MultiKeyring.MultiKeyring(
        generatorKeyring := None(),
        childKeyrings := [failingKeyring, failingKeyring]
    );

    var materials := Crypto.DecryptionMaterials(
      encryptionContext:=encryptionContext,
      algorithmSuiteId := Crypto.ALG_AES_256_GCM_IV12_TAG16_HKDF_SHA256,
      verificationKey := None(),
      plaintextDataKey:=None()
    );

    var result := multiKeyring.OnDecrypt(Crypto.OnDecryptInput(materials:=materials, encryptedDataKeys:=[]));
    expect result.IsFailure();
    expect result.error.GetMessage() == "Unable to decrypt data key:\n\nFailure\nFailure";
  }

  method setupRawAesKeyring(encryptionContext: Crypto.EncryptionContext) returns (res: Crypto.IKeyring) {
    var namespace, name := TestUtils.NamespaceAndName(0);
    var rawAESKeyring := new RawAESKeyring.RawAESKeyring(
      namespace,
      name,
      seq(32, i => 0),
      AESEncryption.AES_GCM(
        keyLength := 32 as AESEncryption.KeyLength,
        tagLength := 16 as AESEncryption.TagLength,
        ivLength := 12 as AESEncryption.IVLength
      ));
    return rawAESKeyring;
  }

  /*
   * A keyring which always returns a specific static set of materials. Used for testing.
   */
  class StaticKeyring extends Crypto.IKeyring {
    const encryptionMaterials: Option<Crypto.EncryptionMaterials>;
    const decryptionMaterials: Option<Crypto.DecryptionMaterials>;

    constructor(
      encryptionMaterials: Option<Crypto.EncryptionMaterials>,
      decryptionMaterials: Option<Crypto.DecryptionMaterials>
    )
    {
      this.encryptionMaterials := encryptionMaterials;
      this.decryptionMaterials := decryptionMaterials;
    }

    method OnEncrypt(input: Crypto.OnEncryptInput)
      returns (res: Result<Crypto.OnEncryptOutput, Crypto.IAwsCryptographicMaterialProvidersException>)
    {
      if this.encryptionMaterials.Some? {
        return Success(Crypto.OnEncryptOutput(materials:=encryptionMaterials.value));
      } else {
        var exception := new Crypto.AwsCryptographicMaterialProvidersException("Failure");
        return Failure(exception);
      }
    }

    method OnDecrypt(input: Crypto.OnDecryptInput)
      returns (res: Result<Crypto.OnDecryptOutput, Crypto.IAwsCryptographicMaterialProvidersException>)
    {
      if this.decryptionMaterials.Some? {
        return Success(Crypto.OnDecryptOutput(materials:=decryptionMaterials.value));
      } else {
        var exception := new Crypto.AwsCryptographicMaterialProvidersException("Failure");
        return Failure(exception);
      }
    }
  }

  /*
   * Keyring that fails all calls. Used for testing
   */
  class FailingKeyring extends Crypto.IKeyring {

    constructor() {}

    method OnEncrypt(input: Crypto.OnEncryptInput)
      returns (res: Result<Crypto.OnEncryptOutput, Crypto.IAwsCryptographicMaterialProvidersException>)
    {
      var exception := new Crypto.AwsCryptographicMaterialProvidersException("Failure");
      return Failure(exception);
    }

    method OnDecrypt(input: Crypto.OnDecryptInput)
      returns (res: Result<Crypto.OnDecryptOutput, Crypto.IAwsCryptographicMaterialProvidersException>)
    {
      var exception := new Crypto.AwsCryptographicMaterialProvidersException("Failure");
      return Failure(exception);
    }
  }
}
