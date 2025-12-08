defmodule LlmAsyncWeb.Index do
  use LlmAsyncWeb, :live_view

  def mount(_params, _session, socket) do
    socket =
      assign(socket, text: "実行ボタンを押してください")
      |> assign(input_text: "Elixirについて一言で教えてください")
      |> assign(btn: true)
      |> assign(talking: false)
      |> assign(old_count: 1)
      |> assign(sentences: [])
      |> assign(talking_no: 0)

    {:ok, socket}
  end

  def handle_event("start", _, socket) do
    pid = self()
    input_text = socket.assigns.input_text

    socket =
      assign(socket, btn: false)
      |> assign(text: "")
      |> assign_async(:ret, fn -> run(pid, input_text) end)

    {:noreply, socket}
  end

  def handle_event("update_text", %{"text" => new_text}, socket) do
    {:noreply, assign(socket, input_text: new_text)}
  end

  def handle_event("voice_playback_finished", _, socket) do
    talking_no = socket.assigns.talking_no + 1
    sentences = socket.assigns.sentences
    text = Enum.at(sentences, talking_no)
    max_talking_no = Enum.count(sentences) - 1

    socket =
      if talking_no < max_talking_no do
        IO.puts("#{talking_no} #{max_talking_no} : #{text}")

        push_event(socket, "synthesize_and_play", %{
          "text" => text,
          "speaker_id" => String.to_integer("1")
        })
        |> assign(talking_no: talking_no)
      else
        assign(socket, talking_no: 0)
      end

    {:noreply, socket}
  end

  def handle_info(%{"done" => false, "response" => response}, socket) do
    talking = socket.assigns.talking
    old_count = socket.assigns.old_count
    text = socket.assigns.text <> response
    sentences = String.split(text, ["。", "、"])

    new_count = Enum.count(sentences)

    socket =
      if old_count == 1 && new_count == 2 do
        text =
          Enum.at(sentences, old_count - 1)

        IO.puts(text)

        push_event(socket, "synthesize_and_play", %{
          "text" => text,
          "speaker_id" => String.to_integer("1")
        })
      else
        socket
      end

    socket =
      assign(socket, sentences: sentences)
      |> assign(talking: talking)
      |> assign(old_count: new_count)
      |> assign(text: text)

    {:noreply, socket}
  end

  def handle_info(%{"done" => true}, socket) do
    socket =
      assign(socket, btn: true)

    {:noreply, socket}
  end

  def run(pid, text) do
    client = Ollama.init()

    {:ok, stream} =
      Ollama.completion(client,
        model: "gemma3:27b",
        prompt: text,
        stream: true
      )

    stream
    |> Stream.each(&Process.send(pid, &1, []))
    |> Stream.run()

    {:ok, %{ret: :ok}}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div id="voicex" class="p-5" phx-hook="Voicex">
        <form>
          <textarea id="text_input" name="text" phx-change="update_text" class="input w-[400px]">{@input_text}</textarea>
        </form>
        <button disabled={!@btn} class="btn" phx-click="start">実行</button>
        <div :for={sentence <- @sentences}>
          {sentence}
        </div>
      </div>
    </Layouts.app>
    """
  end
end
