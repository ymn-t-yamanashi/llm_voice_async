defmodule LlmAsyncWeb.Index do
  use LlmAsyncWeb, :live_view

  def mount(_params, _session, socket) do
    socket =
      assign(socket, text: "実行ボタンを押してください")
      |> assign(input_text: "Elixirについて教えてください")
      |> assign(btn: true)
      |> assign(talking: false)
      |> assign(old_count: 1)
      |> assign(sentences: [])

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

  def handle_info(%{"done" => false, "response" => response}, socket) do
    talking = socket.assigns.talking
    old_count = socket.assigns.old_count
    text = socket.assigns.text <> response
    sentences = String.split(text, ["。", "、"])

    new_count = Enum.count(sentences)

    if old_count != new_count do
      Enum.at(sentences, old_count - 1)
      |> IO.inspect()
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
      <div class="p-5">
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
