package com.github.orhan.geofencer;

import java.util.LinkedList;
import java.util.Queue;

public class GoogleServiceCommandExecutor implements IGoogleServiceCommandListener {
    private Queue<AbstractGoogleServiceCommand> commandsToExecute;
    private boolean isExecuting = false;

    public GoogleServiceCommandExecutor() {
        commandsToExecute = new LinkedList<AbstractGoogleServiceCommand>();
    }

    public void QueueToExecute(AbstractGoogleServiceCommand command) {
        commandsToExecute.add(command);
        if (!isExecuting) ExecuteNext();
    }

    private void ExecuteNext() {
        if (commandsToExecute.isEmpty()) return;
        isExecuting = true;
        AbstractGoogleServiceCommand command = commandsToExecute.poll();
        command.addListener(this);
        command.Execute();
    }

    @Override
    public void onCommandExecuted() {
        // TODO Auto-generated method stub
        isExecuting = false;
        ExecuteNext();
    }
}
