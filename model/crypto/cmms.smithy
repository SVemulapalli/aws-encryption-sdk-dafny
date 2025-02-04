namespace aws.encryptionSdk.core

use aws.polymorph#reference
use aws.polymorph#positional
use aws.polymorph#extendable

@extendable
resource CryptographicMaterialsManager {
    operations: [GetEncryptionMaterials, DecryptMaterials]
}

/////////////////
// CMM Structures

@reference(resource: CryptographicMaterialsManager)
structure CryptographicMaterialsManagerReference {}

/////////////////
// CMM Operations

operation GetEncryptionMaterials {
    input: GetEncryptionMaterialsInput,
    output: GetEncryptionMaterialsOutput,
}

structure GetEncryptionMaterialsInput {
    @required
    encryptionContext: EncryptionContext,

    @required
    commitmentPolicy: CommitmentPolicy,

    algorithmSuiteId: AlgorithmSuiteId,

    maxPlaintextLength: Long
}

structure GetEncryptionMaterialsOutput {
    @required
    encryptionMaterials: EncryptionMaterials
}

operation DecryptMaterials {
    input: DecryptMaterialsInput,
    output: DecryptMaterialsOutput,
}

structure DecryptMaterialsInput {
    @required
    algorithmSuiteId: AlgorithmSuiteId,

    @required
    commitmentPolicy: CommitmentPolicy,

    @required
    encryptedDataKeys: EncryptedDataKeyList,

    @required
    encryptionContext: EncryptionContext,
}

structure DecryptMaterialsOutput {
    @required
    decryptionMaterials: DecryptionMaterials 
}


///////////////////
// CMM Constructors

@positional
structure CreateCryptographicMaterialsManagerOutput {
    materialsManager: CryptographicMaterialsManagerReference 
}

operation CreateDefaultCryptographicMaterialsManager {
    input: CreateDefaultCryptographicMaterialsManagerInput,
    output: CreateCryptographicMaterialsManagerOutput,
}

structure CreateDefaultCryptographicMaterialsManagerInput {
    @required
    keyring: KeyringReference 
}
