// Copyright Amazon.com Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

using System;
using Aws.EncryptionSdk.Core;
using
    Aws.EncryptionSdk.Core
    ;

namespace Aws.EncryptionSdk.Core
{
    public class CreateAwsKmsMrkDiscoveryMultiKeyringInput
    {
        private System.Collections.Generic.List<string> _regions;
        private Aws.EncryptionSdk.Core.DiscoveryFilter _discoveryFilter;
        private Aws.EncryptionSdk.Core.IClientSupplier _clientSupplier;
        private System.Collections.Generic.List<string> _grantTokens;

        public System.Collections.Generic.List<string> Regions
        {
            get { return this._regions; }
            set { this._regions = value; }
        }

        internal bool IsSetRegions()
        {
            return this._regions != null;
        }

        public Aws.EncryptionSdk.Core.DiscoveryFilter DiscoveryFilter
        {
            get { return this._discoveryFilter; }
            set { this._discoveryFilter = value; }
        }

        internal bool IsSetDiscoveryFilter()
        {
            return this._discoveryFilter != null;
        }

        public Aws.EncryptionSdk.Core.IClientSupplier ClientSupplier
        {
            get { return this._clientSupplier; }
            set { this._clientSupplier = value; }
        }

        internal bool IsSetClientSupplier()
        {
            return this._clientSupplier != null;
        }

        public System.Collections.Generic.List<string> GrantTokens
        {
            get { return this._grantTokens; }
            set { this._grantTokens = value; }
        }

        internal bool IsSetGrantTokens()
        {
            return this._grantTokens != null;
        }

        public void Validate()
        {
            if (!IsSetRegions()) throw new System.ArgumentException("Missing value for required member 'regions'");
        }
    }
}