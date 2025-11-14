// translate.js
export async function translateText(text, targetLang = "en", sourceLang = "auto") {
  if (!text || !text.trim()) return text;
  
  console.log(`🔄 Translating: "${text.substring(0, 50)}..." from ${sourceLang} to ${targetLang}`);

  // Enhanced list of translation endpoints with fallbacks
  const endpoints = [
    {
      url: "https://translate.terraprint.co/translate",
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        q: text,
        source: sourceLang,
        target: targetLang,
        format: "text",
      })
    },
    {
      url: "https://libretranslate.de/translate",
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        q: text,
        source: sourceLang,
        target: targetLang,
        format: "text",
      })
    },
    {
      url: "https://translate.argosopentech.com/translate",
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        q: text,
        source: sourceLang,
        target: targetLang,
        format: "text",
      })
    },
    // Google Translate API proxy as fallback
    {
      url: `https://translate.googleapis.com/translate_a/single?client=gtx&sl=${sourceLang}&tl=${targetLang}&dt=t&q=${encodeURIComponent(text)}`,
      method: "GET",
      headers: {},
      body: null
    }
  ];

  for (const endpoint of endpoints) {
    try {
      console.log(`Trying endpoint: ${endpoint.url}`);
      
      const options = {
        method: endpoint.method,
        headers: endpoint.headers,
      };
      
      if (endpoint.body) {
        options.body = endpoint.body;
      }

      const res = await fetch(endpoint.url, options);
      
      if (!res.ok) {
        console.warn(`Endpoint ${endpoint.url} returned status: ${res.status}`);
        continue;
      }

      const data = await res.json();
      console.log('Translation response:', data);

      let translatedText = text; // fallback to original

      // Handle different response formats
      if (endpoint.url.includes('translate.googleapis.com')) {
        // Google Translate format
        if (Array.isArray(data) && data[0] && Array.isArray(data[0])) {
          translatedText = data[0].map(item => item[0]).join('');
        }
      } else {
        // LibreTranslate format
        translatedText = data?.translatedText || data?.translation || data?.translated_text;
      }

      if (translatedText && translatedText !== text) {
        console.log(`✅ Translation successful: "${text}" → "${translatedText}"`);
        return translatedText;
      } else {
        console.warn('Translation returned same text or empty');
        continue;
      }

    } catch (err) {
      console.warn(`Translation failed with ${endpoint.url}:`, err.message);
      // Continue to next endpoint
    }
  }

  console.warn('❌ All translation endpoints failed, returning original text');
  return text; // fallback to original text
}

// Alternative translation function using MyMemory API
export async function translateTextAlternative(text, targetLang = "en", sourceLang = "auto") {
  try {
    const response = await fetch(
      `https://api.mymemory.translated.net/get?q=${encodeURIComponent(text)}&langpair=${sourceLang}|${targetLang}`
    );
    
    const data = await response.json();
    
    if (data.responseStatus === 200) {
      return data.responseData.translatedText;
    }
  } catch (error) {
    console.warn('MyMemory translation failed:', error);
  }
  
  return text;
}