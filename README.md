<h1>Purview Email Compliance Tools</h1>

<p>
A set of <strong>safety‑first PowerShell functions</strong> for creating,
executing, and purging Microsoft Purview eDiscovery (Compliance Search)
email results.
</p>

<p>
These tools intentionally wrap native Purview cmdlets with
<strong>explicit lifecycle control</strong>, <strong>predictable defaults</strong>,
and <strong>operator‑focused guardrails</strong>, reducing the risk of accidental
wide‑scope searches or destructive purge actions.
</p>

<hr/>

<h2>Overview</h2>

<p>
Microsoft Purview Compliance Search and purge operations are powerful but easy
to misuse:
</p>

<ul>
  <li>Searches and purge actions run <strong>asynchronously</strong></li>
  <li>Recipient filters do <strong>not</strong> limit mailbox scope by default</li>
  <li>Date boundaries are <strong>day‑based</strong>, not time‑based</li>
  <li>Purge actions must be <strong>explicitly serialized</strong></li>
  <li>Confirmation prompts can mislead under pressure</li>
</ul>

<p>
This module provides a clear, deliberate lifecycle model:
</p>

<pre><code>
New → Invoke → Invoke (Purge)
</code></pre>

<p>
Each step is explicit, verifiable, and designed to behave predictably —
even when run quickly or while tired.
</p>

<hr/>

<h2>Requirements</h2>

<ul>
  <li>PowerShell 7.x (recommended)</li>
  <li><code>ExchangeOnlineManagement</code> module</li>
  <li>Purview eDiscovery permissions</li>
  <li>Active connections to:
    <ul>
      <li>Exchange Online</li>
      <li>Purview eDiscovery (IPPSSession)</li>
    </ul>
  </li>
</ul>

<p>
Connection requirements are enforced internally by the module.
</p>

<hr/>

<h2>Cmdlet Overview</h2>

<h3><code>New-PurviewEmailSearch</code></h3>
<ul>
  <li>Creates a new Purview Compliance Search definition</li>
  <li>Builds KQL safely from sender, recipient, subject, and date filters</li>
  <li>Applies conservative mailbox‑scope defaults</li>
  <li>Does <strong>not</strong> execute or purge unless explicitly instructed</li>
</ul>

<h3><code>Invoke-PurviewEmailSearch</code></h3>
<ul>
  <li>Executes an existing Compliance Search</li>
  <li>Waits for completion</li>
  <li>Returns the updated Compliance Search object</li>
</ul>

<h3><code>Invoke-PurviewEmailPurge</code></h3>
<ul>
  <li>Purges items returned by a completed Compliance Search</li>
  <li>Supports SoftDelete (default) and HardDelete</li>
  <li>Serializes purge actions correctly</li>
  <li>Re‑runs the search between purge passes</li>
  <li>Safely aborts if progress stalls</li>
</ul>

<hr/>

<h2>Design Principles</h2>

<h3>Explicit Lifecycle Control</h3>

<p>
No cmdlet performs hidden work:
</p>

<ul>
  <li>Searches are not executed unless explicitly invoked</li>
  <li>Purges cannot run unless searches have completed</li>
  <li>Destructive operations require confirmation</li>
</ul>

<p>
This avoids surprise behavior and accidental execution.
</p>

<h3>Safe Mailbox Scoping</h3>

<p>
Native Purview behavior does not restrict mailbox scope when filtering
by recipients. This module intentionally changes that:
</p>

<ul>
  <li>By default, specifying recipients limits mailbox scope</li>
  <li>Use <code>-SearchAllMailboxes</code> to explicitly widen scope</li>
</ul>

<p>
This prevents accidental tenant‑wide searches or purges.
</p>

<h3>Date Handling</h3>

<ul>
  <li>Dates are treated as <strong>whole calendar days</strong></li>
  <li>End dates use <strong>non‑inclusive boundaries</strong></li>
  <li>Avoids UTC, DST, and partial‑day errors</li>
</ul>

<h3>Asynchronous‑Aware Operations</h3>

<p>
All searches and purge actions are treated as long‑running jobs with:
</p>

<ul>
  <li>Explicit polling</li>
  <li>Progress verification</li>
  <li>Stall detection</li>
  <li>Bounded retries</li>
</ul>

<hr/>

<h2>Typical Usage</h2>

<h3>Create a search only</h3>

<pre><code>
New-PurviewEmailSearch `
  -SenderAddress a@contoso.com `
  -SubjectBody "Quarterly Report"
</code></pre>

<p>
Returns the generated Compliance Search name.
</p>

<h3>Create and execute a search</h3>

<pre><code>
New-PurviewEmailSearch `
  -RecipientAddresses b@contoso.com `
  -SubjectBody "Incident" `
  -StartDate "2026-05-01" `
  -EndDate "2026-05-12" `
  -ExecuteSearch
</code></pre>

<h3>Create, execute, and purge</h3>

<pre><code>
New-PurviewEmailSearch `
  -RecipientAddresses c@contoso.com `
  -SubjectBody "Confidential" `
  -ExecuteSearch `
  -ExecutePurge
</code></pre>

<h3>Pipeline‑based workflow (recommended)</h3>

<pre><code>
New-PurviewEmailSearch `
  -RecipientAddresses d@contoso.com `
  -SubjectBody "Confidential" `
  -ExecuteSearch `
  -PassThru |
Invoke-PurviewEmailPurge
</code></pre>

<hr/>

<h2>SoftDelete vs HardDelete</h2>

<ul>
  <li>
    <strong>SoftDelete (default)</strong>
    <ul>
      <li>Items moved to Recoverable Items</li>
      <li>Subject to retention policy</li>
    </ul>
  </li>
  <li>
    <strong>HardDelete</strong>
    <ul>
      <li>Permanently removes items</li>
      <li>Cannot be undone</li>
      <li>Explicit confirmation required</li>
    </ul>
  </li>
</ul>

<hr/>

<h2>Error Handling & Safety</h2>

<p>
The module fails fast and clearly if:
</p>

<ul>
  <li>A search does not exist</li>
  <li>A search has not completed</li>
  <li>No search results are found</li>
  <li>A purge makes no progress</li>
  <li>Required permissions are missing</li>
  <li>The user cancels execution</li>
</ul>

<p>
Silent failure and partial execution are intentionally avoided.
</p>

<hr/>

<h2>Help & Documentation</h2>

<p>
Each cmdlet includes full comment‑based help:
</p>

<pre><code>
Get-Help New-PurviewEmailSearch -Full
Get-Help Invoke-PurviewEmailSearch -Full
Get-Help Invoke-PurviewEmailPurge -Full
</code></pre>

<p>
This README explains <em>why</em> the design behaves as it does;
<code>Get-Help</code> explains <em>how</em> to use each cmdlet.
</p>

<hr/>

<h2>Intended Audience</h2>

<ul>
  <li>Exchange / Microsoft 365 administrators</li>
  <li>Security &amp; Compliance engineers</li>
  <li>Incident response workflows</li>
  <li>eDiscovery operations</li>
</ul>

<p>
This is an opinionated, safety‑first toolset — not a thin wrapper over Purview.
</p>

<hr/>

<h2>Final Notes</h2>

<p>
If unsure what a command will do:
</p>

<ul>
  <li>Use <code>-Verbose</code></li>
  <li>Use <code>-WhatIf</code></li>
  <li>Inspect generated KQL</li>
  <li>Prefer SoftDelete first</li>
</ul>

<p>
These tools are designed for deliberate, auditable, and repeatable operations —
not fast, casual execution.
</p>