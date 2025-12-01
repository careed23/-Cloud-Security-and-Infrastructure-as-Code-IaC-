<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Staff-Level Security Architecture</title>
    <!-- Load Tailwind CSS -->
    <script src="https://cdn.tailwindcss.com"></script>
    <style>
        /* Custom font */
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@100..900&display=swap');
        body {
            font-family: 'Inter', sans-serif;
        }
        /* Custom scrollbar for a darker aesthetic */
        ::-webkit-scrollbar {
            width: 8px;
        }
        ::-webkit-scrollbar-track {
            background: #111827; /* Dark background */
        }
        ::-webkit-scrollbar-thumb {
            background: #4B5563; /* Gray thumb */
            border-radius: 4px;
        }
        ::-webkit-scrollbar-thumb:hover {
            background: #6B7280;
        }
    </style>
</head>
<body class="bg-gray-900 text-gray-200 min-h-screen p-4 sm:p-8">

    <div class="max-w-6xl mx-auto">
        <!-- Header -->
        <header class="text-center py-6 border-b border-indigo-700/50 mb-10">
            <h1 class="text-3xl sm:text-4xl font-extrabold text-indigo-400 tracking-tight">
                Staff-Level Security Architecture
            </h1>
            <p class="mt-2 text-lg text-gray-400">
                IaC (Infrastructure as Code) and PaC (Policy as Code) Enforcement
            </p>
        </header>

        <!-- Core Philosophy -->
        <section class="mb-12 p-6 bg-gray-800 rounded-xl shadow-2xl shadow-indigo-900/30">
            <p class="text-xl leading-relaxed text-gray-300">
                This architecture demonstrates a comprehensive approach to securing a cloud environment by enforcing security and compliance
                <span class="font-semibold text-green-400">*at creation time* (IaC)</span> and
                <span class="font-semibold text-green-400">*at deployment time* (PaC)</span>.
            </p>
        </section>

        <!-- 1. Secure Reference Architecture (IaC) -->
        <section class="mb-12">
            <h2 class="text-2xl sm:text-3xl font-bold mb-6 text-yellow-300 flex items-center">
                <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="w-6 h-6 mr-3 text-yellow-500"><path d="M12 21c-4.418 0-8-3.582-8-8s3.582-8 8-8 8 3.582 8 8-3.582 8-8 8z"></path><path d="M12 12v4"></path><path d="M12 8h.01"></path></svg>
                1. Secure Reference Architecture (AWS Landing Zone)
            </h2>
            <p class="mb-6 text-gray-400">
                The Terraform configuration defines a **Secure Landing Zone**, a mandated baseline that all applications must inherit. 
            </p>

            <div class="grid md:grid-cols-3 gap-6">
                <!-- Component Card: Networking -->
                <div class="bg-gray-800 p-5 rounded-xl border border-gray-700 hover:border-indigo-500 transition duration-300">
                    <h3 class="font-semibold text-lg text-indigo-400 mb-2">Networking (VPC & Subnets)</h3>
                    <p class="text-sm text-gray-400">
                        <span class="font-medium text-white">Security Rationale:</span> The use of only **Private Subnets** for compute resources ensures workloads are not directly exposed to the internet, prioritizing isolation.
                    </p>
                </div>

                <!-- Component Card: Auditing -->
                <div class="bg-gray-800 p-5 rounded-xl border border-gray-700 hover:border-indigo-500 transition duration-300">
                    <h3 class="font-semibold text-lg text-indigo-400 mb-2">Centralized Auditing</h3>
                    <p class="text-sm text-gray-400">
                        <span class="font-medium text-white">Security Rationale:</span> All API activity is logged globally and written to an immutable, encrypted S3 bucket and streamed to CloudWatch. This ensures **non-repudiation** and provides real-time monitoring for security anomalies.
                    </p>
                </div>

                <!-- Component Card: IAM -->
                <div class="bg-gray-800 p-5 rounded-xl border border-gray-700 hover:border-indigo-500 transition duration-300">
                    <h3 class="font-semibold text-lg text-indigo-400 mb-2">Least Privilege IAM</h3>
                    <p class="text-sm text-gray-400">
                        <span class="font-medium text-white">Security Rationale:</span> The `SecureComputeRole` is defined with an explicit, minimal `compute_policy`. This prevents lateral movement by adhering strictly to the **Principle of Least Privilege**.
                    </p>
                </div>
            </div>

            <!-- Impact Summary -->
            <div class="mt-8 bg-indigo-900/30 p-4 rounded-lg border-l-4 border-indigo-500">
                <p class="font-medium text-sm text-indigo-300 uppercase">Staff-Level Impact (IaC):</p>
                <p class="text-gray-300 text-base">Defining this single source of truth for IaC prevents decentralized, insecure deployments and drastically lowers the blast radius of misconfigurations across the organization.</p>
            </div>
        </section>

        <!-- 2. Admission Controller / Policy as Code (PaC) -->
        <section class="mb-12">
            <h2 class="text-2xl sm:text-3xl font-bold mb-6 text-yellow-300 flex items-center">
                <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="w-6 h-6 mr-3 text-yellow-500"><path d="M12 21.6c-4.4 0-8-3.6-8-8v-6.6c0-1.1.9-2 2-2h12c1.1 0 2 .9 2 2v6.6c0 4.4-3.6 8-8 8z"></path><path d="M12 17v-4"></path></svg>
                2. Admission Controller / Policy as Code (PaC)
            </h2>
            <p class="mb-6 text-gray-400">
                The Rego policy (OPA) acts as a **mandatory security gate** in the deployment pipeline, operating *before* a resource is committed to the API server. 
            </p>

            <div class="grid md:grid-cols-2 gap-6">
                <!-- Policy Card: Deny Root -->
                <div class="bg-gray-800 p-5 rounded-xl border border-gray-700 hover:border-red-500 transition duration-300">
                    <h3 class="font-semibold text-lg text-red-400 mb-2 font-mono">`deny_root_user`</h3>
                    <p class="text-sm text-gray-400">
                        <span class="font-medium text-white">Security Rationale:</span> Enforces the critical standard that processes inside containers must not run with root privileges. This is a fundamental defense-in-depth measure to prevent **privilege escalation** upon container compromise.
                    </p>
                </div>

                <!-- Policy Card: Deny Latest -->
                <div class="bg-gray-800 p-5 rounded-xl border border-gray-700 hover:border-red-500 transition duration-300">
                    <h3 class="font-semibold text-lg text-red-400 mb-2 font-mono">`deny_latest_tag`</h3>
                    <p class="text-sm text-gray-400">
                        <span class="font-medium text-white">Security Rationale:</span> Forcing the use of immutable, versioned tags (e.g., `v1.2.3`) ensures that deployments are **auditable** and **reproducible** (secure rollbacks are guaranteed). The `:latest` tag is mutable and non-deterministic.
                    </p>
                </div>
            </div>

            <!-- Impact Summary -->
            <div class="mt-8 bg-red-900/30 p-4 rounded-lg border-l-4 border-red-500">
                <p class="font-medium text-sm text-red-300 uppercase">Staff-Level Impact (PaC):</p>
                <p class="text-gray-300 text-base">This demonstrates the ability to translate high-level security requirements directly into executable, enforced policies at the deployment level, **shifting security left** into the CI/CD process.</p>
            </div>
        </section>

        <footer class="text-center mt-12 pt-6 border-t border-gray-700/50 text-gray-500 text-sm">
            Staff Engineering Security Reference &copy; 2025
        </footer>
    </div>

</body>
</html>
