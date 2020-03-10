using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using ArtDevops.Models;
using ArtDevops.Extensions;
using Microsoft.Bot.Builder;
using Microsoft.Bot.Builder.Dialogs;
using Microsoft.Bot.Schema;
using Microsoft.Extensions.Logging;

namespace ArtDevops.Bots
{
    public class MainBot<T> : ActivityHandler where T : Dialog
    {
        private const string WebChatChannelId = "webchat";
        private readonly Dialog _dialog;
        private readonly BotState _conversationState;
        private readonly BotState _userState;
        private readonly ILogger _logger;
        private IStatePropertyAccessor<GlobalUserState> _globalStateAccessor;

        public MainBot(ConversationState conversationState, UserState userState, T dialog, ILogger<MainBot<T>> logger)
        {
            if (conversationState == null)
            {
                throw new System.ArgumentNullException(nameof(conversationState));
            }

            if (logger == null)
            {
                throw new System.ArgumentNullException(nameof(logger));
            }

            _conversationState = conversationState;
            _userState = userState;
            _logger = logger;
            _dialog = dialog;
            _globalStateAccessor = _userState.CreateProperty<GlobalUserState>(nameof(GlobalUserState));

            _logger.LogTrace("Turn start.");
        }

        public override async Task OnTurnAsync(ITurnContext turnContext, CancellationToken cancellationToken)
        {
            await base.OnTurnAsync(turnContext, cancellationToken);

            await _conversationState.SaveChangesAsync(turnContext, false, cancellationToken);
            await _userState.SaveChangesAsync(turnContext, false, cancellationToken);
        }

        protected override async Task OnMessageActivityAsync(ITurnContext<IMessageActivity> turnContext, CancellationToken cancellationToken)
        {
            var state = await _globalStateAccessor.GetAsync(turnContext, () => new GlobalUserState());

            turnContext.Activity.Text = (string.IsNullOrEmpty(turnContext.Activity.Text)) ? turnContext.Activity.Value.ToString() : turnContext.Activity.Text;

            if (state.DidBotWelcomeUser == false)
            {
                state.DidBotWelcomeUser = true;

                await turnContext.SendActivityAsync($"{String.Format(MainBotStrings.Welcome_name)}", cancellationToken: cancellationToken);
                var name = turnContext.Activity.Text ?? string.Empty;
                    
                await _dialog.Run(turnContext, _conversationState.CreateProperty<DialogState>(nameof(DialogState)), cancellationToken: cancellationToken);
            }
            else
            {
                await _dialog.Run(turnContext, _conversationState.CreateProperty<DialogState>(nameof(DialogState)), cancellationToken: cancellationToken);
            }
        }

        protected override async Task OnMembersAddedAsync(IList<ChannelAccount> membersAdded, ITurnContext<IConversationUpdateActivity> turnContext, CancellationToken cancellationToken)
        {
            foreach (var member in membersAdded)
            {
                if (member.Id != turnContext.Activity.Recipient.Id)
                {
                    if (turnContext.Activity.ChannelId.ToLower() != WebChatChannelId)
                    {
                        var state = await _globalStateAccessor.GetAsync(turnContext, () => new GlobalUserState());
                        state.DidBotWelcomeUser = true;

                        var name = member.Name ?? string.Empty;
                        await turnContext.SendActivityAsync($"{String.Format(MainBotStrings.WelcomeToTheConversation_name)}", cancellationToken: cancellationToken);

                        await _dialog.Run(turnContext, _conversationState.CreateProperty<DialogState>(nameof(DialogState)), cancellationToken: cancellationToken);
                    }
                }
            }
        }
    }
}
