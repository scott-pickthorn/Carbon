﻿// Copyright 2012 Aaron Jensen
//   
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//  
//    http://www.apache.org/licenses/LICENSE-2.0
//   
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Security.Principal;
using System.Text;

namespace Carbon
{
    public sealed class Identity
    {
        private Identity(string domain, string name, SecurityIdentifier sid, IdentityType type)
        {
            Domain = domain;
            Name = name;
            Sid = sid;
            Type = type;
        }

        public string Domain { get; private set; }

        public string FullName
        {
            get
            {
                return (string.IsNullOrEmpty(Domain)) 
                    ? Name 
                    : string.Format("{0}\\{1}", Domain, Name);
            }
        }

        public string Name { get; private set; }

        public SecurityIdentifier Sid { get; private set; }

        public IdentityType Type { get; private set; }

        public override bool Equals(object obj)
        {
            if (obj == null || typeof (Identity) != obj.GetType())
            {
                return false;
            }

            return Sid.Equals(((Identity) obj).Sid);
        }

        public override int GetHashCode()
        {
            return Sid.GetHashCode();
        }

        public override string ToString()
        {
            return FullName;
        }

        public static Identity FindByName(string name)
        {
            byte[] rawSid = null;
            uint cbSid = 0;
            var referencedDomainName = new StringBuilder();
            var cchReferencedDomainName = (uint) referencedDomainName.Capacity;
            IdentityType sidUse;

            int err;
            if (AdvApi32.LookupAccountName(null, name, rawSid, ref cbSid, referencedDomainName, ref cchReferencedDomainName, out sidUse))
            {
                throw new Win32Exception();
            }

            err = Marshal.GetLastWin32Error();
            if (err == Win32ErrorCodes.INSUFFICIENT_BUFFER || err == Win32ErrorCodes.INVALID_FLAGS)
            {
                rawSid = new byte[cbSid];
                referencedDomainName.EnsureCapacity((int) cchReferencedDomainName);
                if (!AdvApi32.LookupAccountName(null, name, rawSid, ref cbSid, referencedDomainName, ref cchReferencedDomainName, out sidUse))
                {
                    throw new Win32Exception();
                }
            }
            else if (err == Win32ErrorCodes.NONE_MAPPED)
            {
                // Couldn't find the account.
                return null;
            }
            else
            {
                throw new Win32Exception();
            }

            IntPtr ptrSid;
            if (!AdvApi32.ConvertSidToStringSid(rawSid, out ptrSid))
            {
                throw new Win32Exception();
            }

            var sid = new SecurityIdentifier(rawSid, 0);
            Kernel32.LocalFree(ptrSid);
            var ntAccount = sid.Translate(typeof (NTAccount));
            var domainName = referencedDomainName.ToString();
            var accountName = ntAccount.Value;
            if (!string.IsNullOrEmpty(domainName))
            {
                var domainPrefix = string.Format("{0}\\", domainName);
                if (accountName.StartsWith(domainPrefix))
                {
                    accountName = accountName.Replace(domainPrefix, "");
                }
            }
            return new Identity(domainName, accountName, sid, sidUse);
        }
    }
}
