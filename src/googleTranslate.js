import { useEffect, useState } from "react";

export default function GoogleTranslate() {
  const [ready, setReady] = useState(false);
  const [currentLang, setCurrentLang] = useState("en");

  const languages = [
    { code: "en", label: "English 🇬🇧" },
    { code: "zh-CN", label: "Chinese 🇨🇳" },
    { code: "es", label: "Spanish 🇪🇸" },
    { code: "fr", label: "French 🇫🇷" },
    { code: "hi", label: "Hindi 🇮🇳" },
    { code: "ta", label: "Tamil 🇮🇳" },
    { code: "ms", label: "Malay 🇲🇾" },
    { code: "ja", label: "Japanese 🇯🇵" },
    { code: "ko", label: "Korean 🇰🇷" },
  ];

  useEffect(() => {
    // --- 1️⃣ Add hidden Google container ---
    if (!document.getElementById("google_translate_element")) {
      const div = document.createElement("div");
      div.id = "google_translate_element";
      div.style.display = "none";
      document.body.appendChild(div);
    }

    // --- 2️⃣ Add styles to hide Google UI ---
    const style = document.createElement("style");
    style.innerHTML = `
      .goog-te-banner-frame { display: none !important; }
      body { top: 0 !important; bottom: 500px !important; }
      .goog-logo-link { display: none !important; }
      .goog-te-gadget { font-size: 0 !important; }
    `;
    document.head.appendChild(style);

    // --- 3️⃣ Define callback (only once) ---
    window.googleTranslateElementInit = () => {
      new window.google.translate.TranslateElement(
        {
          pageLanguage: "en",
          includedLanguages: languages.map((l) => l.code).join(","),
          autoDisplay: false,
        },
        "google_translate_element"
      );

      // Wait for the dropdown to exist
      const checkExist = setInterval(() => {
        const select = document.querySelector(".goog-te-combo");
        if (select) {
          clearInterval(checkExist);
          setReady(true);
        }
      }, 100);
    };

    // --- 4️⃣ Load script if not already loaded ---
    const existingScript = document.getElementById("google-translate-script");
    if (!existingScript) {
      const script = document.createElement("script");
      script.id = "google-translate-script";
      script.src =
        "https://translate.google.com/translate_a/element.js?cb=googleTranslateElementInit";
      script.async = true;
      document.body.appendChild(script);
    } else if (window.google?.translate?.TranslateElement) {
      // If already loaded (cached)
      window.googleTranslateElementInit();
    }

    return () => {
      document.head.removeChild(style);
    };
  }, []);

  // --- Change language manually ---
  const changeLanguage = (lang) => {
    const select = document.querySelector(".goog-te-combo");
    if (!select) {
      alert("Translator is still loading...");
      return;
    }
    select.value = lang;
    select.dispatchEvent(new Event("change"));
    setCurrentLang(lang);
    localStorage.setItem("selectedLang", lang);
  };

  // --- Restore previously saved language ---
  useEffect(() => {
    if (!ready) return;
    const savedLang = localStorage.getItem("selectedLang");
    if (savedLang) {
      const select = document.querySelector(".goog-te-combo");
      if (select) {
        select.value = savedLang;
        select.dispatchEvent(new Event("change"));
        setCurrentLang(savedLang);
      }
    }
  }, [ready]);

  return (
    <div
      style={{
        position: "fixed",
        top: "80px",
        right: "10px",
        zIndex: 9999,
        background: "#fff",
        borderRadius: "8px",
        padding: "6px 10px",
        boxShadow: "0 2px 6px rgba(0,0,0,0.2)",
        border: "1px solid #e0e0e0",
      }}
    >
      <select
        value={currentLang}
        onChange={(e) => changeLanguage(e.target.value)}
        disabled={!ready}
        style={{
          padding: "6px 10px",
          border: "1px solid #ccc",
          borderRadius: "6px",
          background: ready ? "#fff" : "#f5f5f5",
          cursor: ready ? "pointer" : "not-allowed",
          minWidth: "160px",
          fontSize: "14px",
          fontWeight: "500",
          color: ready ? "#333" : "#999",
          outline: "none",
        }}
      >
        {languages.map((lang) => (
          <option key={lang.code} value={lang.code}>
            {lang.label}
          </option>
        ))}
      </select>

      {!ready && (
        <div
          style={{
            fontSize: "10px",
            color: "#666",
            marginTop: "4px",
            textAlign: "center",
            fontStyle: "italic",
          }}
        >
          Loading translator...
        </div>
      )}
    </div>
  );
}
