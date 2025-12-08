
// VOICEVOX EngineのURL
const VOICEVOX_URL = "http://localhost:50021"; 

Voicex = {
    // ライフサイクルコールバック (要素がDOMに追加され、LiveViewと接続された時に実行)
    mounted() {
        // Elixirサーバー側から送信されるイベントをリッスン
        // イベント名: "synthesize_and_play"
        // ペイロード: { text: "...", speaker_id: N }
        this.handleEvent("synthesize_and_play", ({ text, speaker_id }) => {
            this.speakText(text, speaker_id);
        });
    },

    // --- 1. VOICEVOX API通信関数 (Hook内部関数として定義) ---

    /**
     * 1. VOICEVOX APIを使って音声合成クエリを取得します (audio_query)。
     */
    async fetchAudioQuery(text, speakerId) {
        const queryParams = new URLSearchParams({ text: text, speaker: speakerId });
        const queryUrl = `${VOICEVOX_URL}/audio_query?${queryParams}`;

        const queryResponse = await fetch(queryUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' }
        });

        if (!queryResponse.ok) {
            throw new Error(`audio_query failed with status ${queryResponse.status}`);
        }
        return await queryResponse.json();
    },

    /**
     * 2. VOICEVOX APIを使って音声合成を実行し、WAV形式のBlobを取得します (synthesis)。
     */
    async fetchSynthesis(audioQuery, speakerId) {
        const synthesisParams = new URLSearchParams({ speaker: speakerId });
        const synthesisUrl = `${VOICEVOX_URL}/synthesis?${synthesisParams}`;

        const synthesisResponse = await fetch(synthesisUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(audioQuery)
        });

        if (!synthesisResponse.ok) {
            throw new Error(`synthesis failed with status ${synthesisResponse.status}`);
        }
        return await synthesisResponse.blob();
    },

    // --- 2. コアロジック関数 (Hook内部関数として定義) ---

    /**
     * VOICEVOX APIを使って音声データ(Blob)を取得する純粋なロジック関数。
     */
    async synthesizeTextToBlob(text, speakerId) {
        const trimmedText = text.trim();
        if (!trimmedText) {
            throw new Error("Text input is empty."); 
        }

        // 1. クエリ取得 (Hook内部関数を呼び出し)
        const audioQuery = await this.fetchAudioQuery(trimmedText, speakerId);
        
        // 2. 音声合成 (Hook内部関数を呼び出し)
        const wavBlob = await this.fetchSynthesis(audioQuery, speakerId);

        return wavBlob;
    },

    // --- 3. メインアプリケーション関数 (Hookの主要ロジック) ---

    /**
     * 音声合成と再生を実行するメイン関数。
     */
    async speakText(text, speakerId) {
        try {
            // 1. コアロジックを呼び出し、Blobを取得 (Hook内部関数を呼び出し)
            const wavBlob = await this.synthesizeTextToBlob(text, speakerId);
            
            // 2. JavaScript側で <audio> 要素を生成
            const audioPlayer = new Audio();
            
            // 3. 再生ロジック
            const audioUrl = URL.createObjectURL(wavBlob);
            audioPlayer.src = audioUrl;
            
            // 4. 再生開始
            await audioPlayer.play();

            // 5. 再生終了後のクリーンアップ
            audioPlayer.onended = () => {
                URL.revokeObjectURL(audioUrl);
            };
            audioPlayer.onerror = () => {
                 URL.revokeObjectURL(audioUrl);
            };

        } catch (error) {
            console.error("致命的なエラーが発生しました:", error.message, error);
            
            // エラーロギング
            if (error.message.includes("Text input is empty")) {
                console.error("エラー: テキストが入力されていません。");
            } else if (error.name === "NotAllowedError") {
                console.warn("警告: 再生がブラウザによってブロックされました。");
            } else {
                console.error(`VOICEVOX Engine 接続エラー: ポート (${VOICEVOX_URL}) を確認してください。`);
            }
        } 
    }
};

export default Voicex
