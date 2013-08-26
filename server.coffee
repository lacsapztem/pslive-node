

require('coffee-script')
express = require('express')
routes = require('./routes')
user = require('./routes/user')
http = require('http')
path = require('path')
md5 = require('MD5')
mu = require('mu2')
check = require('validator').check
sanitize = require('validator').sanitize

app = express()

# functions
replaceURLWithHTMLLinks = (text) ->
  exp = /(\b(https?|ftp|file):\/\/[-A-Z0-9+&@#\/%?=~_|!:,.;]*[-A-Z0-9+&@#\/%=~_|])/ig
  return text.replace(exp,"<a href='$1'>$1</a>")



#all environments
app.use require('connect-assets')()
app.set('port', process.env.PORT || 3000)
app.set('views', __dirname + '/views');
app.set('view engine', 'jade');
app.use(express.favicon("/images/fav.png"));
app.use(express.logger('dev'));
app.use(express.bodyParser());
app.use(express.methodOverride());
app.use(app.router);
app.use(express.static(path.join(__dirname, 'public')));

#development only
if ('development' == app.get('env'))
  app.use(express.errorHandler());


app.get('/', routes.index);
app.get('/admin', routes.admin);
app.get('/users', user.list);


httpServer = http.createServer(app).listen(app.get('port'), ->
  console.log('Express server listening on port ' + app.get('port'))
)

io = require('socket.io').listen(httpServer)

io.configure ->
  io.set("transports", ["xhr-polling"])
  io.set("polling duration", 10)


users = new Object()
messages = []
history = 10
admin_password = process.env.PSLIVE_ADMIN_PASSWORD
livedraw_iframe = "Pas de dessins ce soir :("

io.sockets.on 'connection', (socket) ->


  # gestion des utilisateurs
  me = false  

  for key, value of users
    socket.emit('newuser',value)

  for message in messages
    socket.emit('nwmsg',message)

  socket.emit('new-drawings',livedraw_iframe)

  socket.on 'login', (user) ->

    try 
      check(user.mail).isEmail()
    catch
      socket.emit('error',"Email invalide")

    try
      check(user.username).len(3,30)
    catch
      socket.emit('error',"Le nom d'utilisateur doit être compris entre 3 et 30 lettres")

    try 
      check(user.mail).isEmail()
      check(user.username).len(3,30)

      me = user
      me.id = user.mail.replace('@','-').replace(/\./gi, "-")
      me.avatar = 'https://gravatar.com/avatar/' + md5(user.mail) + '?s=50'
      socket.emit('logged')
      users[me.id] = me
      users_name = (user.id for user in users)	

      io.sockets.emit('newuser',me)


  socket.on 'disconnect', ->
    return false if(!me)
    delete users[me.id]
    socket.broadcast.emit('disuser',me)


  # gestion des mesages
  socket.on 'nwmsg', (message) ->
    message.user = me
    date = new Date()

    message.message = replaceURLWithHTMLLinks(sanitize(message.message).escape())

    message.h = date.getHours()
    message.m = date.getMinutes()
    messages.push message
    messages.shift() if (messages.length > history)

    io.sockets.emit('nwmsg',message)

  # Changement d'iframe
  socket.on 'new-iframe', (message) ->
    if message.password == admin_password
      livedraw_iframe = message.iframe
      io.sockets.emit('new-drawings',livedraw_iframe)

  # test

  # socket.on 'test', ->
  # 	console.log(users)






