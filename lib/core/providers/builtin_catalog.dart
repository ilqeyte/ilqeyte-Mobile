import '../models/provider_models.dart';

/// A provider the app already knows about: base URL, protocol and quirks are
/// baked in, so the only thing left to enter is an API key. Models are then
/// fetched live from the endpoint and picked from a list — never typed by hand.
class BuiltinProvider {
  const BuiltinProvider({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.site,
    required this.kind,
    this.protocol = LlmProtocol.openaiCompatible,
    this.ensureV1 = true,
    this.experimental = false,
    this.localServer = false,
    this.note,
  });

  /// Unique within a [ProviderKind].
  final String id;
  final String name;

  /// The API root. [joinEndpoint] appends the path — and a `/v1` when the
  /// endpoint expects one.
  final String baseUrl;

  /// Public homepage: feeds the logo and the "get an API key" link.
  final String site;
  final ProviderKind kind;
  final LlmProtocol protocol;

  /// False for endpoints whose API root is not `/v1` — Gemini, Novita, Zhipu,
  /// DeepInfra and friends.
  final bool ensureV1;

  /// True when the wire shape is a best effort rather than a documented one.
  final bool experimental;

  /// A locally-served endpoint (Ollama, vLLM…): the key field is optional and
  /// a placeholder is stored so the agent loop's key check passes.
  final bool localServer;

  final String? note;

  /// A real logo for every provider without shipping a single image asset:
  /// Google's favicon service at 128px. [ProviderLogo] falls back to a monogram
  /// whenever the fetch fails, so a dead URL never breaks the UI.
  String get logoUrl =>
      'https://www.google.com/s2/favicons?domain=${Uri.parse(site).host}&sz=128';
}

/// Every built-in entry, grouped by capability kind. The settings pages filter
/// this list, so adding a provider here is all it takes to make it appear.
const List<BuiltinProvider> builtinProviders = [
  // ---------------------------- chat / agent ----------------------------
  BuiltinProvider(
      id: 'openai',
      name: 'OpenAI',
      baseUrl: 'https://api.openai.com/v1',
      site: 'https://platform.openai.com',
      kind: ProviderKind.agent),
  BuiltinProvider(
      id: 'anthropic',
      name: 'Anthropic',
      baseUrl: 'https://api.anthropic.com',
      site: 'https://console.anthropic.com',
      kind: ProviderKind.agent,
      protocol: LlmProtocol.anthropic),
  BuiltinProvider(
      id: 'gemini',
      name: 'Google Gemini',
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
      site: 'https://ai.google.dev',
      kind: ProviderKind.agent,
      ensureV1: false),
  BuiltinProvider(
      id: 'xai',
      name: 'xAI (Grok)',
      baseUrl: 'https://api.x.ai/v1',
      site: 'https://x.ai',
      kind: ProviderKind.agent),
  BuiltinProvider(
      id: 'deepseek',
      name: 'DeepSeek',
      baseUrl: 'https://api.deepseek.com',
      site: 'https://deepseek.com',
      kind: ProviderKind.agent),
  BuiltinProvider(
      id: 'openrouter',
      name: 'OpenRouter',
      baseUrl: 'https://openrouter.ai/api/v1',
      site: 'https://openrouter.ai',
      kind: ProviderKind.agent),
  BuiltinProvider(
      id: 'together',
      name: 'Together AI',
      baseUrl: 'https://api.together.xyz/v1',
      site: 'https://together.ai',
      kind: ProviderKind.agent),
  BuiltinProvider(
      id: 'groq',
      name: 'Groq',
      baseUrl: 'https://api.groq.com/openai/v1',
      site: 'https://groq.com',
      kind: ProviderKind.agent),
  BuiltinProvider(
      id: 'mistral',
      name: 'Mistral AI',
      baseUrl: 'https://api.mistral.ai/v1',
      site: 'https://mistral.ai',
      kind: ProviderKind.agent),
  BuiltinProvider(
      id: 'cohere',
      name: 'Cohere',
      baseUrl: 'https://api.cohere.ai/compatibility/v1',
      site: 'https://cohere.com',
      kind: ProviderKind.agent),
  BuiltinProvider(
      id: 'fireworks',
      name: 'Fireworks AI',
      baseUrl: 'https://api.fireworks.ai/inference/v1',
      site: 'https://fireworks.ai',
      kind: ProviderKind.agent),
  BuiltinProvider(
      id: 'perplexity',
      name: 'Perplexity',
      baseUrl: 'https://api.perplexity.ai',
      site: 'https://perplexity.ai',
      kind: ProviderKind.agent),
  BuiltinProvider(
      id: 'deepinfra',
      name: 'DeepInfra',
      baseUrl: 'https://api.deepinfra.com/v1/openai',
      site: 'https://deepinfra.com',
      kind: ProviderKind.agent,
      ensureV1: false),
  BuiltinProvider(
      id: 'novita',
      name: 'Novita AI',
      baseUrl: 'https://api.novita.ai/v3/openai',
      site: 'https://novita.ai',
      kind: ProviderKind.agent,
      ensureV1: false),
  BuiltinProvider(
      id: 'cerebras',
      name: 'Cerebras',
      baseUrl: 'https://api.cerebras.ai/v1',
      site: 'https://cerebras.ai',
      kind: ProviderKind.agent),
  BuiltinProvider(
      id: 'sambanova',
      name: 'SambaNova',
      baseUrl: 'https://api.sambanova.ai/v1',
      site: 'https://sambanova.ai',
      kind: ProviderKind.agent),
  BuiltinProvider(
      id: 'ai21',
      name: 'AI21',
      baseUrl: 'https://api.ai21.ai/v1',
      site: 'https://ai21.com',
      kind: ProviderKind.agent),
  BuiltinProvider(
      id: 'alephalpha',
      name: 'Aleph Alpha',
      baseUrl: 'https://api.aleph-alpha.com/v1',
      site: 'https://aleph-alpha.com',
      kind: ProviderKind.agent),
  BuiltinProvider(
      id: 'anyscale',
      name: 'Anyscale',
      baseUrl: 'https://api.endpoints.anyscale.com/v1',
      site: 'https://www.anyscale.com',
      kind: ProviderKind.agent),
  BuiltinProvider(
      id: 'baseten',
      name: 'Baseten',
      baseUrl: 'https://inference.baseten.co/v1',
      site: 'https://baseten.co',
      kind: ProviderKind.agent),
  BuiltinProvider(
      id: 'replicate',
      name: 'Replicate',
      baseUrl: 'https://api.replicate.com/v1',
      site: 'https://replicate.com',
      kind: ProviderKind.agent,
      experimental: true,
      note: 'OpenAI-compatible chat for select models.'),
  BuiltinProvider(
      id: 'scaleway',
      name: 'Scaleway',
      baseUrl: 'https://api.scaleway.ai/domain/v1beta1',
      site: 'https://www.scaleway.com',
      kind: ProviderKind.agent,
      ensureV1: false),
  BuiltinProvider(
      id: 'ovhcloud',
      name: 'OVHcloud AI',
      baseUrl: 'https://endpoints.ai.cloud.ovh.net/v1',
      site: 'https://www.ovhcloud.com',
      kind: ProviderKind.agent),
  BuiltinProvider(
      id: 'ionos',
      name: 'IONOS AI',
      baseUrl: 'https://api.openai.prod-ionos.com/v1',
      site: 'https://www.ionos.com',
      kind: ProviderKind.agent),
  BuiltinProvider(
      id: 'nscale',
      name: 'Nscale',
      baseUrl: 'https://inference.eu-1.nscale.ai/v1',
      site: 'https://nscale.com',
      kind: ProviderKind.agent),
  BuiltinProvider(
      id: 'nebius',
      name: 'Nebius AI Studio',
      baseUrl: 'https://api.studio.nebius.ai/v1',
      site: 'https://nebius.com',
      kind: ProviderKind.agent),
  BuiltinProvider(
      id: 'lambda',
      name: 'Lambda',
      baseUrl: 'https://api.lambdalabs.com/v1',
      site: 'https://lambdalabs.com',
      kind: ProviderKind.agent),
  BuiltinProvider(
      id: 'nvidia',
      name: 'NVIDIA NIM',
      baseUrl: 'https://integrate.api.nvidia.com/v1',
      site: 'https://build.nvidia.com',
      kind: ProviderKind.agent),
  BuiltinProvider(
      id: 'featherless',
      name: 'Featherless',
      baseUrl: 'https://api.featherless.ai/v1',
      site: 'https://featherless.ai',
      kind: ProviderKind.agent),
  BuiltinProvider(
      id: 'chutes',
      name: 'Chutes',
      baseUrl: 'https://api.chutes.ai/v1',
      site: 'https://chutes.ai',
      kind: ProviderKind.agent),
  BuiltinProvider(
      id: 'inception',
      name: 'Inception',
      baseUrl: 'https://api.inceptionlabs.ai/v1',
      site: 'https://inceptionlabs.ai',
      kind: ProviderKind.agent),
  BuiltinProvider(
      id: 'hyperbolic',
      name: 'Hyperbolic',
      baseUrl: 'https://api.hyperbolic.xyz/v1',
      site: 'https://hyperbolic.xyz',
      kind: ProviderKind.agent),
  BuiltinProvider(
      id: 'aimlapi',
      name: 'AI/ML API',
      baseUrl: 'https://api.aimlapi.com/v1',
      site: 'https://aimlapi.com',
      kind: ProviderKind.agent),
  BuiltinProvider(
      id: 'huggingface',
      name: 'Hugging Face',
      baseUrl: 'https://router.huggingface.co/v1',
      site: 'https://huggingface.co',
      kind: ProviderKind.agent),
  BuiltinProvider(
      id: 'friendli',
      name: 'FriendliAI',
      baseUrl: 'https://api.friendli.ai/dedicated/v1',
      site: 'https://friendli.ai',
      kind: ProviderKind.agent,
      ensureV1: false),
  BuiltinProvider(
      id: 'galadriel',
      name: 'Galadriel',
      baseUrl: 'https://api.galadriel.com/v1',
      site: 'https://galadriel.ai',
      kind: ProviderKind.agent),
  BuiltinProvider(
      id: 'gmi',
      name: 'GMI Cloud',
      baseUrl: 'https://api.gmi-serving.com/v1',
      site: 'https://gmi.ai',
      kind: ProviderKind.agent),
  BuiltinProvider(
      id: 'gradient',
      name: 'Gradient AI',
      baseUrl: 'https://api.gradient.ai/api/v1',
      site: 'https://gradient.ai',
      kind: ProviderKind.agent,
      ensureV1: false),
  BuiltinProvider(
      id: 'lemonade',
      name: 'Lemonade AI',
      baseUrl: 'https://api.lemonade.ai/v1',
      site: 'https://lemonade.ai',
      kind: ProviderKind.agent),
  BuiltinProvider(
      id: 'minimax',
      name: 'MiniMax',
      baseUrl: 'https://api.minimax.chat/v1',
      site: 'https://www.minimaxi.com',
      kind: ProviderKind.agent),
  BuiltinProvider(
      id: 'moonshot',
      name: 'Moonshot (Kimi)',
      baseUrl: 'https://api.moonshot.cn/v1',
      site: 'https://platform.moonshot.cn',
      kind: ProviderKind.agent),
  BuiltinProvider(
      id: 'zhipu',
      name: 'Zhipu (GLM)',
      baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      site: 'https://open.bigmodel.cn',
      kind: ProviderKind.agent,
      ensureV1: false),
  BuiltinProvider(
      id: 'dashscope',
      name: 'Qwen · DashScope China',
      baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      site: 'https://www.aliyun.com',
      kind: ProviderKind.agent),
  BuiltinProvider(
      id: 'dashscope-intl',
      name: 'Qwen · Model Studio International',
      baseUrl: 'https://dashscope-intl.aliyuncs.com/compatible-mode/v1',
      site: 'https://www.alibabacloud.com',
      kind: ProviderKind.agent),
  BuiltinProvider(id: 'volcengine', name: 'Volcengine Ark (Doubao)', baseUrl: 'https://ark.cn-beijing.volces.com/api/v3', site: 'https://www.volcengine.com', kind: ProviderKind.agent, ensureV1: false, experimental: true),
  BuiltinProvider(id: 'hunyuan', name: 'Tencent Hunyuan', baseUrl: 'https://api.hunyuan.cloud.tencent.com/v1', site: 'https://cloud.tencent.com', kind: ProviderKind.agent),
  BuiltinProvider(id: 'siliconflow', name: 'SiliconFlow', baseUrl: 'https://api.siliconflow.cn/v1', site: 'https://siliconflow.cn', kind: ProviderKind.agent),
  BuiltinProvider(id: 'baichuan', name: 'Baichuan', baseUrl: 'https://api.baichuan-ai.com/v1', site: 'https://www.baichuan-ai.com', kind: ProviderKind.agent),
  BuiltinProvider(id: 'stepfun', name: 'StepFun', baseUrl: 'https://api.stepfun.com/v1', site: 'https://www.stepfun.com', kind: ProviderKind.agent),
  BuiltinProvider(id: 'lingyi', name: '01.AI (Lingyi)', baseUrl: 'https://api.lingyiwanwu.com/v1', site: 'https://platform.lingyiwanwu.com', kind: ProviderKind.agent),
  BuiltinProvider(id: 'nlpcloud', name: 'NLP Cloud', baseUrl: 'https://api.nlpcloud.io/v1', site: 'https://nlpcloud.io', kind: ProviderKind.agent),
  BuiltinProvider(id: 'nanogpt', name: 'NanoGPT', baseUrl: 'https://api.nanogpt.com/v1', site: 'https://nanogpt.com', kind: ProviderKind.agent),
  BuiltinProvider(id: 'poe', name: 'Poe', baseUrl: 'https://api.poe.com/v1', site: 'https://poe.com', kind: ProviderKind.agent),
  BuiltinProvider(id: 'sarvam', name: 'Sarvam AI', baseUrl: 'https://api.sarvam.ai/v1', site: 'https://sarvam.ai', kind: ProviderKind.agent),
  BuiltinProvider(id: 'cometapi', name: 'CometAPI', baseUrl: 'https://api.cometapi.com/v1', site: 'https://cometapi.com', kind: ProviderKind.agent),
  BuiltinProvider(id: 'vercel', name: 'Vercel AI Gateway', baseUrl: 'https://ai-gateway.vercel.sh/v1', site: 'https://vercel.com', kind: ProviderKind.agent),
  BuiltinProvider(id: 'meta', name: 'Meta Model API', baseUrl: 'https://api.metamodel.ai/v1', site: 'https://ai.meta.com', kind: ProviderKind.agent, experimental: true),
  BuiltinProvider(id: 'github', name: 'GitHub Models', baseUrl: 'https://models.inference.azure.com', site: 'https://github.com', kind: ProviderKind.agent, experimental: true, note: 'Use a GitHub personal access token as the API key.'),

  // ----------------------------- local servers -----------------------------
  BuiltinProvider(id: 'ollama', name: 'Ollama (local)', baseUrl: 'http://localhost:11434/v1', site: 'https://ollama.com', kind: ProviderKind.agent, localServer: true, note: 'No key needed — run "ollama serve". Any value works in the key field.'),
  BuiltinProvider(id: 'lmstudio', name: 'LM Studio (local)', baseUrl: 'http://localhost:1234/v1', site: 'https://lmstudio.ai', kind: ProviderKind.agent, localServer: true, note: 'Start the local server in LM Studio first.'),
  BuiltinProvider(id: 'localai', name: 'LocalAI (local)', baseUrl: 'http://localhost:8080/v1', site: 'https://localai.io', kind: ProviderKind.agent, localServer: true),
  BuiltinProvider(id: 'vllm', name: 'vLLM (local)', baseUrl: 'http://localhost:8000/v1', site: 'https://docs.vllm.ai', kind: ProviderKind.agent, localServer: true),
  BuiltinProvider(id: 'llamafile', name: 'llamafile (local)', baseUrl: 'http://localhost:8080/v1', site: 'https://github.com/Mozilla-Ocho/llamafile', kind: ProviderKind.agent, localServer: true),
  BuiltinProvider(id: 'docker', name: 'Docker Model Runner', baseUrl: 'http://localhost:12434/v1', site: 'https://www.docker.com', kind: ProviderKind.agent, localServer: true),

  // ------------------------------- images -------------------------------
  BuiltinProvider(id: 'openai-images', name: 'OpenAI Images', baseUrl: 'https://api.openai.com/v1', site: 'https://platform.openai.com', kind: ProviderKind.image, note: 'DALL·E 3 and gpt-image-1.'),
  BuiltinProvider(id: 'together-images', name: 'Together AI Images', baseUrl: 'https://api.together.xyz/v1', site: 'https://together.ai', kind: ProviderKind.image, note: 'FLUX and Stable Diffusion models.'),
  BuiltinProvider(id: 'recraft', name: 'Recraft', baseUrl: 'https://external.api.recraft.ai/v1', site: 'https://www.recraft.ai', kind: ProviderKind.image),
  BuiltinProvider(id: 'deepinfra-images', name: 'DeepInfra Images', baseUrl: 'https://api.deepinfra.com/v1/openai', site: 'https://deepinfra.com', kind: ProviderKind.image, ensureV1: false, experimental: true),
  BuiltinProvider(id: 'aimlapi-images', name: 'AI/ML API Images', baseUrl: 'https://api.aimlapi.com/v1', site: 'https://aimlapi.com', kind: ProviderKind.image, experimental: true),
  BuiltinProvider(id: 'segmind', name: 'Segmind', baseUrl: 'https://api.segmind.com/v1', site: 'https://www.segmind.com', kind: ProviderKind.image, experimental: true, note: 'Model-specific paths under /v1.'),
  BuiltinProvider(id: 'stability', name: 'Stability AI', baseUrl: 'https://api.stability.ai/v2beta', site: 'https://stability.ai', kind: ProviderKind.image, ensureV1: false, experimental: true, note: 'Stable Image REST API.'),
  BuiltinProvider(id: 'fal', name: 'fal', baseUrl: 'https://fal.run', site: 'https://fal.ai', kind: ProviderKind.image, ensureV1: false, experimental: true, note: 'fal queue API — model-specific endpoints.'),
  BuiltinProvider(id: 'leonardo', name: 'Leonardo.ai', baseUrl: 'https://cloud.leonardo.ai/api/rest/v1', site: 'https://leonardo.ai', kind: ProviderKind.image, ensureV1: false, experimental: true),
  BuiltinProvider(id: 'ideogram', name: 'Ideogram', baseUrl: 'https://api.ideogram.ai/v1', site: 'https://ideogram.ai', kind: ProviderKind.image, experimental: true),
  BuiltinProvider(id: 'bfl', name: 'Black Forest Labs', baseUrl: 'https://api.bfl.ai', site: 'https://bfl.ai', kind: ProviderKind.image, ensureV1: false, experimental: true, note: 'FLUX.1 family.'),

  // ------------------------------- videos -------------------------------
  // Video endpoints are not standardized, so these are best-effort: the request
  // is sent in the common OpenAI-style shape and the provider's answer — a job
  // id, a poll URL, a status — is surfaced as-is.
  BuiltinProvider(id: 'minimax-video', name: 'MiniMax Hailuo', baseUrl: 'https://api.minimax.chat/v1', site: 'https://www.minimaxi.com', kind: ProviderKind.video, experimental: true),
  BuiltinProvider(id: 'replicate-video', name: 'Replicate', baseUrl: 'https://api.replicate.com/v1', site: 'https://replicate.com', kind: ProviderKind.video, experimental: true),
  BuiltinProvider(id: 'runway', name: 'Runway', baseUrl: 'https://api.runwayml.com/v1', site: 'https://runwayml.com', kind: ProviderKind.video, experimental: true),
  BuiltinProvider(id: 'luma', name: 'Luma Dream Machine', baseUrl: 'https://api.lumalabs.ai/dream-machine/v1', site: 'https://lumalabs.ai', kind: ProviderKind.video, ensureV1: false, experimental: true),
  BuiltinProvider(id: 'pika', name: 'Pika', baseUrl: 'https://api.pika.art', site: 'https://pika.art', kind: ProviderKind.video, ensureV1: false, experimental: true),
  BuiltinProvider(id: 'kling', name: 'Kling', baseUrl: 'https://api.klingai.com/v1', site: 'https://klingai.com', kind: ProviderKind.video, experimental: true),
  BuiltinProvider(id: 'haiper', name: 'Haiper', baseUrl: 'https://api.haiper.ai/v1', site: 'https://haiper.ai', kind: ProviderKind.video, experimental: true),
  BuiltinProvider(id: 'volcengine-video', name: 'Volcengine Seedance', baseUrl: 'https://ark.cn-beijing.volces.com/api/v3', site: 'https://www.volcengine.com', kind: ProviderKind.video, ensureV1: false, experimental: true),
];

/// The entries shown on one settings page, filtered and alphabetized.
List<BuiltinProvider> builtinsFor(ProviderKind kind) =>
    (builtinProviders.where((p) => p.kind == kind).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())));

/// Traces a saved provider back to the catalog entry that created it.
BuiltinProvider? builtinById(String id, ProviderKind kind) {
  for (final p in builtinProviders) {
    if (p.id == id && p.kind == kind) return p;
  }
  return null;
}
