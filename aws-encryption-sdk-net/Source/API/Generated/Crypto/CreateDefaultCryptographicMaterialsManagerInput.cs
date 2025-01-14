// Copyright Amazon.com Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0
// Do not modify this file. This file is machine generated, and any changes to it will be overwritten.

using System;
using AWS.EncryptionSDK.Core;

namespace AWS.EncryptionSDK.Core
{
    public class CreateDefaultCryptographicMaterialsManagerInput
    {
        private AWS.EncryptionSDK.Core.IKeyring _keyring;

        public AWS.EncryptionSDK.Core.IKeyring Keyring
        {
            get { return this._keyring; }
            set { this._keyring = value; }
        }

        internal bool IsSetKeyring()
        {
            return this._keyring != null;
        }

        public void Validate()
        {
            if (!IsSetKeyring()) throw new System.ArgumentException("Missing value for required property 'Keyring'");
        }
    }
}
