import { useEffect, useState } from 'react';

const TranslationPopup = () => {
  const [showPopup, setShowPopup] = useState(false);

  useEffect(() => {
    const script = document.createElement("script");
    script.src = "//translate.google.com/translate_a/element.js?cb=googleTranslateElementInit";
    document.body.appendChild(script);

    window.googleTranslateElementInit = () => {
      new window.google.translate.TranslateElement(
        {
          pageLanguage: "en",
          layout: window.google.translate.TranslateElement.InlineLayout.SIMPLE
        },
        "google_translate_element"
      );
    };

    return () => document.body.removeChild(script);
  }, []);

  return (
    <div>
      <button 
        onClick={() => setShowPopup(!showPopup)}
        style={{ position: "fixed", bottom: "20px", right: "20px", zIndex: 999 }}
      >
        Translate
      </button>

      {showPopup && (
        <div 
          style={{
            position: "fixed",
            bottom: "60px",
            right: "20px",
            backgroundColor: "#fff",
            padding: "10px",
            border: "1px solid #ccc",
            borderRadius: "5px",
            boxShadow: "0 4px 8px rgba(0,0,0,0.2)",
            zIndex: 999
          }}
        >
          <div id="google_translate_element"></div>
        </div>
      )}
    </div>
  );
};

export default TranslationPopup;
