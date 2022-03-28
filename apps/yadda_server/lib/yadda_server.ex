defmodule YaddaServer do
  @moduledoc """
  Documentation for `YaddaServer`.
  """
  require Logger

  def accept(port) do
    # The options below mean:
    #
    # 1. `:binary` - receives data as binaries (instead of lists)
    # 2. `packet: :line` - receives data line by line
    # 3. `active: false` - blocks on `:gen_tcp.recv/2` until data is available
    # 4. `reuseaddr: true` - allows us to reuse the address if the listener crashes
    #
    {:ok, socket} = :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true])
    Logger.info("accepting connections on port #{port}")
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    {:ok, pid} = Task.Supervisor.start_child(YaddaServer.TaskSupervisor, fn -> serve(client) end)
    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket)
  end

  defp serve(socket) do
    # the 'with' construct:
    # will retrieve the value returned by the right-side of <-, and
    # match it against the pattern on the left side.
    # if the value matches the pattern, 'with' moves onto the next expression.
    # in case there is no match, the non-matching value is returned
    msg =
      with {:ok, data} <- read_line(socket),
           {:ok, command} <- YaddaServer.Command.parse(data),
           do: YaddaServer.Command.run(command)

    write_line(socket, msg)
    serve(socket)
  end
  # OLD
  # defp serve(socket) do
  #   msg =
  #     case read_line(socket) do
  #       {:ok, data} ->
  #         case YaddaServer.Command.parse(data) do
  #           {:ok, command} ->
  #             YaddaServer.Command.run(command)
  #           {:error, _} = err ->
  #             err
  #         end
  #       {:error, _} = err ->
  #         err
  #     end

  #   write_line(socket, msg)
  #   serve(socket)
  # end
  # OLDEST
  # defp serve(socket) do
  #   # the follwing is equivalent to
  #   # `write_line(read_line(socket), socket)`
  #   #
  #   socket
  #   |> read_line()
  #   |> write_line(socket)

  #   serve(socket)
  # end

  defp read_line(socket) do
    :gen_tcp.recv(socket, 0)
  end

  defp write_line(socket, {:ok, text}) do
    :gen_tcp.send(socket, text)
  end

  defp write_line(socket, {:error, :unknown_command}) do
    # known error, write to the client
    :gen_tcp.send(socket, "UNKNOWN COMMAND\r\n")
  end

  defp write_line(socket, {:error, :not_found}) do
    # known error, write to the client
    :gen_tcp.send(socket, "NOT FOUND\r\n")
  end

  defp write_line(_socket, {:error, :closed}) do
    # the connection was closed, exit politely
    exit(:shutdown)
  end

  defp write_line(socket, {:error, error}) do
    # unknow error, write to the client and exit
    :gen_tcp.send(socket, "ERROR\r\n")
    exit(error)
  end
end
